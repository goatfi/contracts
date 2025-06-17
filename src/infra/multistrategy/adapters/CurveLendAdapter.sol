// SPDX-License-Identifier: GNU AGPLv3

pragma solidity 0.8.27;

import { IERC20, SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC4626 } from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { StrategyAdapterHarvestable } from "src/abstracts/StrategyAdapterHarvestable.sol";
import { ICurveGauge } from "interfaces/curve/ICurveGauge.sol";
import { Errors } from "src/infra/libraries/Errors.sol";

contract CurveLendAdapter is StrategyAdapterHarvestable {
    using SafeERC20 for IERC20;

    /// @notice Struct of Curve addresses needed for this adapter.
    struct CurveLendAddresses {
        address vault;
        address gauge;
    }

    /// @notice The Curve Lending Vault.
    IERC4626 public curveLendVault;

    /// @notice The Curve gauge.
    ICurveGauge public curveGauge;

    /*//////////////////////////////////////////////////////////////////////////
                                     CONSTRUCTOR
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Constructor for the strategy adapter.
    /// @param _multistrategy The address of the multi-strategy contract.
    /// @param _asset The address of the asset.
    /// @param _harvestAddresses Struct of Protocol Addresses.
    /// @param _curveAddresses Struct of Curve Addresses.
    /// @param _name The name of this Strategy Adapter.
    /// @param _id The type identifier of this Strategy Adapter.

    constructor(
        address _multistrategy,
        address _asset,
        HarvestAddresses memory _harvestAddresses,
        CurveLendAddresses memory _curveAddresses,
        string memory _name,
        string memory _id
    ) 
        StrategyAdapterHarvestable(_multistrategy, _asset, _harvestAddresses,_name, _id)
    {   
        curveLendVault = IERC4626(_curveAddresses.vault);
        curveGauge = ICurveGauge(_curveAddresses.gauge);
        _giveAllowances();
    }

    /*//////////////////////////////////////////////////////////////////////////
                            EXTERNAL NON-CONSTANT FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Sets a new Curve gauge.
    /// @dev Only callable by the contract owner. Once the gauge is set, it cannot be changed.
    /// @param _curveGauge The address of the new incentives controller.
    function setCurveGauge(address _curveGauge) external onlyOwner {
        require(address(curveGauge) == address(0) && _curveGauge != address(0), Errors.InvalidGauge());
        curveGauge = ICurveGauge(_curveGauge);
        IERC20(curveLendVault).forceApprove(_curveGauge, type(uint).max);
    }

    /*//////////////////////////////////////////////////////////////////////////
                            INTERNAL CONSTANT FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Total Assets held by this adapter.
    /// @return Returns the total amount of assets held in this adapter.
    function _totalAssets() internal override view returns(uint256) {
        uint256 curveLendVaultShares = address(curveGauge) == address(0) ? curveLendVault.balanceOf(address(this)) : curveGauge.balanceOf(address(this));
        uint256 assetsSupplied = curveLendVault.previewRedeem(curveLendVaultShares);
        uint256 assetBalance = IERC20(asset).balanceOf(address(this));

        return assetsSupplied + assetBalance;
    }

    /// @inheritdoc StrategyAdapterHarvestable
    function _verifyRewardToken(address _token) internal view override {
        require(address(curveGauge) != address(0), Errors.InvalidGauge());
        require(_token != address(curveLendVault) && _token != address(curveGauge), Errors.InvalidRewardToken(_token));
    }

    /*//////////////////////////////////////////////////////////////////////////
                            INTERNAL NON-CONSTANT FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Deposits all the liquidity into the Curve Lend Vault and deposit into the gau.
    function _deposit() internal override {
        uint256 balance = IERC20(asset).balanceOf(address(this));
        curveLendVault.deposit(balance, address(this));
        if(address(curveGauge) != address(0)) {
            uint256 curveLendVaultShares = curveLendVault.balanceOf(address(this));
            curveGauge.deposit(curveLendVaultShares);
        }
    }

    /// @notice Withdraws a specified amount of assets from Curve Lend.
    /// @param _amount The amount of assets to withdraw from the Curve Lend Vault.
    function _withdraw(uint256 _amount) internal override {
        uint256 curveLendSharesNeeded = curveLendVault.previewWithdraw(_amount);
        if(address(curveGauge) != address(0)) curveGauge.withdraw(curveLendSharesNeeded);
        curveLendVault.redeem(curveLendSharesNeeded, address(this), address(this));
    }

    /// @notice Performs an emergency withdrawal of all assets from Curve Lend.
    /// This function is intended for emergency situations where all assets need to be withdrawn immediately.
    function _emergencyWithdraw() internal override {
        uint256 curveLendVaultShares = address(curveGauge) == address(0) ? curveLendVault.balanceOf(address(this)) : curveGauge.balanceOf(address(this));
        if(address(curveGauge) != address(0)) curveGauge.withdraw(curveLendVaultShares);
        curveLendVault.redeem(curveLendVaultShares, address(this), address(this));
    }

    /// @notice Sets the maximum allowance of the base asset for Curve Lend.
    function _giveAllowances() internal override {
        IERC20(asset).forceApprove(address(curveLendVault), type(uint).max);
        if(address(curveGauge) != address(0)) IERC20(curveLendVault).forceApprove(address(curveGauge), type(uint).max);
        IERC20(wrappedGas).forceApprove(swapper, type(uint).max);
    }

    /// @notice Revokes the allowance of the base asset for Curve Lend.
    function _revokeAllowances() internal override {
        IERC20(asset).forceApprove(address(curveLendVault), 0);
        if(address(curveGauge) != address(0)) IERC20(curveLendVault).forceApprove(address(curveGauge), 0);
        IERC20(wrappedGas).forceApprove(swapper, 0);
    }

    /// @inheritdoc StrategyAdapterHarvestable
    function _claim() internal override {
        curveGauge.claim_rewards();
    }
}