// SPDX-License-Identifier: GNU AGPLv3
pragma solidity 0.8.27;

import { IERC20, SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { StrategyAdapterHarvestable } from "./StrategyAdapterHarvestable.sol";
import { Errors } from "src/infra/libraries/Errors.sol";

abstract contract ERC4626AdapterHarvestable is StrategyAdapterHarvestable {
    using SafeERC20 for IERC20;
    using Math for uint256;

    /// @notice The ERC4626 Vault
    IERC4626 public vault;

    /*//////////////////////////////////////////////////////////////////////////
                                     CONSTRUCTOR
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Constructor for the strategy adapter.
    /// @param _multistrategy The address of the multi-strategy contract.
    /// @param _asset The address of the asset.
    /// @param _vault The address of the ERC4626 vault.
    /// @param _name The name of this Strategy Adapter.
    /// @param _id The type identifier of this Strategy Adapter.
    constructor(
        address _multistrategy,
        address _asset,
        address _vault,
        HarvestAddresses memory _harvestAddresses,
        string memory _name,
        string memory _id
    ) 
        StrategyAdapterHarvestable(_multistrategy, _asset, _harvestAddresses, _name, _id)
    {   
        vault = IERC4626(_vault);
        _giveAllowances();
    }

    /*//////////////////////////////////////////////////////////////////////////
                            INTERNAL CONSTANT FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Returns the total amount of assets held in this adapter.
    function _totalAssets() internal override view returns(uint256) {
        uint256 sharesBalance = vault.balanceOf(address(this));
        uint256 assetsSupplied = vault.convertToAssets(sharesBalance);
        uint256 assetBalance = IERC20(asset).balanceOf(address(this));

        return assetsSupplied + assetBalance - 1;
    }

    /// @inheritdoc StrategyAdapterHarvestable
    function _verifyRewardToken(address _token) internal view override {
        require(_token != address(vault), Errors.InvalidRewardToken(_token));
    }

    /*//////////////////////////////////////////////////////////////////////////
                            INTERNAL NON-CONSTANT FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Deposits all the liquidity into the ERC4626 vault.
    function _deposit() internal override {
        uint256 balance = IERC20(asset).balanceOf(address(this));
        vault.deposit(balance, address(this));
    }

    /// @notice Withdraws a specified amount of assets from the ERC4626 vault.
    /// @param _amount The amount of assets to withdraw from the Silo.
    function _withdraw(uint256 _amount) internal override {
        vault.withdraw(_amount, address(this), address(this));
    }

    /// @notice Performs an emergency withdrawal of all assets from the ERC4626 vault.
    /// This function is intended for emergency situations where all assets need to be withdrawn immediately.
    function _emergencyWithdraw() internal override {
        uint256 maxWithdraw = vault.maxWithdraw(address(this));
        if (maxWithdraw > 0) {
            vault.withdraw(maxWithdraw, address(this), address(this));
        }
    }

    /// @notice Sets the maximum allowance of the base asset for the ERC4626 vault.
    function _giveAllowances() internal override {
        IERC20(asset).forceApprove(address(vault), type(uint).max);
        IERC20(wrappedGas).forceApprove(swapper, type(uint).max);
    }

    /// @notice Revokes the allowance of the base asset for the ERC4626 vault.
    function _revokeAllowances() internal override {
        IERC20(asset).forceApprove(address(vault), 0);
        IERC20(wrappedGas).forceApprove(swapper, 0);
    }
}