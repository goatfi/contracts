// SPDX-License-Identifier: GNU AGPLv3

pragma solidity 0.8.27;

import { IERC20, SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { StrategyAdapterHarvestable } from "src/abstracts/StrategyAdapterHarvestable.sol";
import { ISilo, ISiloLens, ISiloRewards, ISiloCollateralToken } from "interfaces/silo/ISilo.sol";
import { IMerklDistributor } from "interfaces/merkl/IDistributor.sol";
import { AssetsArbitrum } from "@addressbook/AssetsArbitrum.sol";
import { Errors } from "src/infra/libraries/Errors.sol";

contract SiloAdapter is StrategyAdapterHarvestable {
    using SafeERC20 for IERC20;
    using Math for uint256;

    struct SiloAddresses {
        address silo;
        address collateral;
        address siloLens;
        address siloRewards;
        address merklDistributor;
    }

    /// @notice This is the main contract where assets are deposited and withdrawn.
    address public silo;

    /// @notice Token used as collateral in the Silo protocol.
    address public collateral;

    /// @notice Used to fetch data related to deposits, interest, and balances.
    ISiloLens siloLens;

    /// @notice Used to claim rewards from the Silo protocol.
    ISiloRewards siloRewards;

    /// @notice Used to manage reward distribution through Merkl.
    IMerklDistributor merklDistributor;

    /// @notice Collateral tokens for which rewards can be claimed.
    address[] private collateralsToClaimFor;

    /*//////////////////////////////////////////////////////////////////////////
                                     CONSTRUCTOR
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Constructor for the strategy adapter.
    /// @param _multistrategy The address of the multi-strategy contract.
    /// @param _asset The address of the asset.
    /// @param _harvestAddresses Struct of Protocol Addresses.
    /// @param _siloAddresses Struct of Silo Addresses.
    /// @param _name The name of this Strategy Adapter.
    /// @param _id The type identifier of this Strategy Adapter.
    constructor(
        address _multistrategy,
        address _asset,
        HarvestAddresses memory _harvestAddresses,
        SiloAddresses memory _siloAddresses,
        string memory _name,
        string memory _id
    ) 
        StrategyAdapterHarvestable(_multistrategy, _asset, _harvestAddresses,_name, _id)
    {
        collateral = _siloAddresses.collateral;
        silo = _siloAddresses.silo;
        siloLens = ISiloLens(_siloAddresses.siloLens);
        siloRewards = ISiloRewards(_siloAddresses.siloRewards);
        merklDistributor = IMerklDistributor(_siloAddresses.merklDistributor);
        collateralsToClaimFor.push(collateral);
        _giveAllowances();
    }

    /*//////////////////////////////////////////////////////////////////////////
                        USER FACING NON-CONSTANT FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    function toggleMerklOperator(address _operator) external onlyOwner {
        merklDistributor.toggleOperator(address(this), _operator);
    }

    /*//////////////////////////////////////////////////////////////////////////
                            INTERNAL CONSTANT FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Returns the total amount of assets held in this adapter.
    function _totalAssets() internal override view returns(uint256) {
        uint256 totalSiloDeposits = siloLens.totalDepositsWithInterest(silo, asset);
        uint256 assetsSupplied = siloLens.balanceOfUnderlying(totalSiloDeposits, collateral, address(this));
        uint256 assetBalance = IERC20(asset).balanceOf(address(this));
        
        return assetsSupplied + assetBalance;
    }

    /// @inheritdoc StrategyAdapterHarvestable
    function _verifyRewardToken(address _token) internal view override {
        require(_token != silo, Errors.InvalidRewardToken(_token));
    }

    /*//////////////////////////////////////////////////////////////////////////
                            INTERNAL NON-CONSTANT FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Deposits all the liquidity into the Silo.
    function _deposit() internal override {
        ISilo(silo).deposit(asset, _liquidity(), false);
    }

    /// @notice Withdraws a specified amount of assets from the Silo.
    /// @param _amount The amount of assets to withdraw from the Silo.
    function _withdraw(uint256 _amount) internal override {
        ISilo(silo).withdraw(asset, _amount, false);
    }

    /// @notice Performs an emergency withdrawal of all assets from the Silo.
    /// This function is intended for emergency situations where all assets need to be withdrawn immediately.
    function _emergencyWithdraw() internal override {
        uint256 totalSiloDeposits = siloLens.totalDepositsWithInterest(silo, asset);
        uint256 assetsSupplied = siloLens.balanceOfUnderlying(totalSiloDeposits, collateral, address(this));
        if (assetsSupplied > 0) {
            ISilo(silo).withdraw(asset, assetsSupplied, false);
        }
    }

    /// @notice Sets the maximum allowance of the base asset for the Silo.
    function _giveAllowances() internal override {
        IERC20(asset).forceApprove(silo, type(uint256).max);
        IERC20(AssetsArbitrum.WETH).forceApprove(swapper, type(uint).max);
    }

    /// @notice Revokes the allowance of the base asset for the Silo.
    function _revokeAllowances() internal override {
        IERC20(asset).forceApprove(silo, 0);
        IERC20(AssetsArbitrum.WETH).forceApprove(swapper, 0);
    }

    /// @inheritdoc StrategyAdapterHarvestable
    function _claim() internal override {
        siloRewards.claimRewardsToSelf(collateralsToClaimFor, type(uint).max);
    }
}