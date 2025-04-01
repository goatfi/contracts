// SPDX-License-Identifier: GNU AGPLv3

pragma solidity 0.8.27;

import { IERC20, SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC4626 } from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import { ICurveVaultXChain } from "interfaces/stakedao/ICurveVaultXChain.sol";
import { IClaimRewardsXChain } from "interfaces/stakedao/IClaimRewardsXChain.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { StrategyAdapterHarvestable } from "src/abstracts/StrategyAdapterHarvestable.sol";
import { Errors } from "src/infra/libraries/Errors.sol";

contract CurveLendSDAdapter is StrategyAdapterHarvestable {
    using SafeERC20 for IERC20;

    struct CurveLendSDAddresses {
        address lendVault;
        address sdVault;
        address sdRewards;
    }

    /// @notice The Curve Lend Vault where crvUSD will be deposited as supply-side liquidity.
    IERC4626 public immutable curveLendVault;

    /// @notice The StakeDAO Vault where Curve Lend Vault shares will be deposited to earn rewards.
    ICurveVaultXChain public immutable stakeDAOVault;

    /// @notice The StakeDAO Claim rewards contract.
    IClaimRewardsXChain public immutable stakeDAORewards;

    /// @notice Address of the StakeDAO Vault Gauge
    address public immutable gauge;

    /// @notice Constructor for the strategy adapter.
    /// @param _multistrategy The address of the multi-strategy contract.
    /// @param _asset The address of the asset.
    /// @param _harvestAddresses Struct of Protocol Addresses.
    /// @param _curveLendSDTAddresses Struct of CurveLend and StakeDAO Addresses.
    /// @param _name The name of this Strategy Adapter.
    /// @param _id The type identifier of this Strategy Adapter.
    constructor(
        address _multistrategy,
        address _asset,
        HarvestAddresses memory _harvestAddresses,
        CurveLendSDAddresses memory _curveLendSDTAddresses,
        string memory _name,
        string memory _id
    ) 
        StrategyAdapterHarvestable(_multistrategy, _asset, _harvestAddresses,_name, _id)
    {   
        curveLendVault = IERC4626(_curveLendSDTAddresses.lendVault);
        stakeDAOVault = ICurveVaultXChain(_curveLendSDTAddresses.sdVault);
        stakeDAORewards = IClaimRewardsXChain(_curveLendSDTAddresses.sdRewards);
        gauge = stakeDAOVault.sdGauge();
        _giveAllowances();
    }

    /*//////////////////////////////////////////////////////////////////////////
                            INTERNAL CONSTANT FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Returns the total amount of assets held in this adapter.
    function _totalAssets() internal override view returns(uint256) {
        uint256 vaultShares = IERC20(gauge).balanceOf(address(this));
        uint256 assetsSupplied = curveLendVault.convertToAssets(vaultShares);
        uint256 assetBalance = IERC20(asset).balanceOf(address(this));

        uint256 total = assetsSupplied + assetBalance;
        return total > 0 ? total - 1 : total;
    }

    /// @inheritdoc StrategyAdapterHarvestable
    function _verifyRewardToken(address _token) internal view override {
        require(
            _token != address(curveLendVault) &&
            _token != address(stakeDAOVault) && 
            _token != address(stakeDAORewards), 
            Errors.InvalidRewardToken(_token));
    }

    /*//////////////////////////////////////////////////////////////////////////
                            INTERNAL NON-CONSTANT FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Deposits all the available base asset balance.
    function _deposit() internal override {
        uint256 balance = IERC20(asset).balanceOf(address(this));
        curveLendVault.deposit(balance, address(this));
        uint256 vaultTokenBalance = curveLendVault.balanceOf(address(this));
        stakeDAOVault.deposit(address(this), vaultTokenBalance);
    }

    /// @notice Withdraws a specified amount of assets.
    /// @param _amount The amount of assets to withdraw.
    function _withdraw(uint256 _amount) internal override {
        uint256 vaultSharesNeeded = curveLendVault.convertToShares(_amount + 1);
        uint256 vaultSharesBalance = IERC20(gauge).balanceOf(address(this));
        uint256 vaultShares = Math.min(vaultSharesNeeded, vaultSharesBalance);
        stakeDAOVault.withdraw(vaultShares);
        curveLendVault.withdraw(_amount, address(this), address(this));
    }

    /// @notice Performs an emergency withdrawal of all assets from StakeDAO and Curve Lend.
    /// This function is intended for emergency situations where all assets need to be withdrawn immediately.
    function _emergencyWithdraw() internal override {
        stakeDAOVault.withdrawAll();
        uint256 vaultBalance = curveLendVault.balanceOf(address(this));
        curveLendVault.redeem(vaultBalance, address(this), address(this));
    }

    /// @notice Sets the maximum allowance of the base asset for the Curve Lend Vault.
    /// and sets the maximum allowance of Curve Lend Vault tokens for StakeDAO
    function _giveAllowances() internal override {
        IERC20(asset).forceApprove(address(curveLendVault), type(uint).max);
        IERC20(curveLendVault).forceApprove(address(stakeDAOVault), type(uint).max);
        IERC20(wrappedGas).forceApprove(swapper, type(uint).max);
    }

    /// @notice Revokes all the allowances.
    function _revokeAllowances() internal override {
        IERC20(asset).forceApprove(address(curveLendVault), 0);
        IERC20(curveLendVault).forceApprove(address(stakeDAOVault), 0);
        IERC20(wrappedGas).forceApprove(swapper, 0);
    }

    /// @inheritdoc StrategyAdapterHarvestable
    function _claim() internal override {
        address[] memory gauges = new address[](1);
        gauges[0] = gauge;
        stakeDAORewards.claimRewards(gauges);
    }
}