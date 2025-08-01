// SPDX-License-Identifier: GNU AGPLv3
pragma solidity 0.8.27;

import { IERC20, SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC4626 } from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import { IRewardVault } from "interfaces/stakedao/IRewardVault.sol";
import { IAccountant } from "interfaces/stakedao/IAccountant.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { StrategyAdapterHarvestable } from "src/abstracts/StrategyAdapterHarvestable.sol";
import { Errors } from "src/infra/libraries/Errors.sol";

contract CurveLendSDV2Adapter is StrategyAdapterHarvestable {
    using SafeERC20 for IERC20;

    /// @notice Struct containing the needed addresses for this adapter.
    struct CurveLendSDV2Addresses {
        address lendVault;
        address sdVault;
    }

    /// @notice The Curve Lend Vault where crvUSD will be deposited as supply-side liquidity.
    IERC4626 public immutable curveLendVault;

    /// @notice The StakeDAO Vault where Curve Lend Vault shares will be deposited to earn rewards.
    IRewardVault public immutable sdVault;

    /// @notice The StakeDAO Accountant contract. Used to track and claim rewards.
    IAccountant public immutable sdAccountant;

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
        CurveLendSDV2Addresses memory _curveLendSDTAddresses,
        string memory _name,
        string memory _id
    ) 
        StrategyAdapterHarvestable(_multistrategy, _asset, _harvestAddresses,_name, _id)
    {   
        curveLendVault = IERC4626(_curveLendSDTAddresses.lendVault);
        sdVault = IRewardVault(_curveLendSDTAddresses.sdVault);
        sdAccountant = IAccountant(IAccountant(sdVault.ACCOUNTANT()));
        gauge = sdVault.gauge();
        _giveAllowances();
    }

    /*//////////////////////////////////////////////////////////////////////////
                            INTERNAL CONSTANT FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Returns the total amount of assets held in this adapter.
    /// @return The total amount of assets held by this adapter.
    function _totalAssets() internal override view returns(uint256) {
        uint256 vaultShares = IERC20(sdVault).balanceOf(address(this));
        uint256 assetsSupplied = curveLendVault.previewRedeem(vaultShares);

        return assetsSupplied + _balance();
    }

    /// @inheritdoc StrategyAdapterHarvestable
    function _verifyRewardToken(address _token) internal view override {
        require(
            _token != address(curveLendVault) &&
            _token != address(sdVault) && 
            _token != address(sdAccountant) &&
            _token != address(gauge),
            Errors.InvalidRewardToken(_token));
        require(
            sdVault.isRewardToken(_token) || 
            _token == sdAccountant.REWARD_TOKEN(), 
            Errors.InvalidRewardToken(_token));
    }

    /*//////////////////////////////////////////////////////////////////////////
                            INTERNAL NON-CONSTANT FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Deposits all the available base asset balance.
    function _deposit() internal override {
        curveLendVault.deposit(_balance(), address(this));
        uint256 vaultTokenBalance = curveLendVault.balanceOf(address(this));
        sdVault.deposit(vaultTokenBalance, address(this));
    }

    /// @notice Withdraws a specified amount of assets.
    /// @param _amount The amount of assets to withdraw.
    function _withdraw(uint256 _amount) internal override {
        uint256 vaultSharesNeeded = curveLendVault.previewWithdraw(_amount);
        uint256 vaultSharesBalance = IERC20(sdVault).balanceOf(address(this));
        uint256 vaultShares = Math.min(vaultSharesNeeded, vaultSharesBalance);
        sdVault.withdraw(vaultShares, address(this), address(this));
        curveLendVault.withdraw(_amount, address(this), address(this));
    }

    /// @notice Performs an emergency withdrawal of all assets from StakeDAO and Curve Lend.
    /// This function is intended for emergency situations where all assets need to be withdrawn immediately.
    function _emergencyWithdraw() internal override {
        uint256 sdVaultSharesBalance = sdVault.balanceOf(address(this));
        sdVault.redeem(sdVaultSharesBalance, address(this), address(this));
        uint256 curveLendVaultSharesBalance = curveLendVault.balanceOf(address(this));
        curveLendVault.redeem(curveLendVaultSharesBalance, address(this), address(this));
    }

    /// @notice Sets the maximum allowance of the base asset for the Curve Lend Vault.
    /// and sets the maximum allowance of Curve Lend Vault tokens for StakeDAO
    function _giveAllowances() internal override {
        IERC20(asset).forceApprove(address(curveLendVault), type(uint).max);
        IERC20(curveLendVault).forceApprove(address(sdVault), type(uint).max);
        IERC20(wrappedGas).forceApprove(swapper, type(uint).max);
    }

    /// @notice Revokes all the allowances.
    function _revokeAllowances() internal override {
        IERC20(asset).forceApprove(address(curveLendVault), 0);
        IERC20(curveLendVault).forceApprove(address(sdVault), 0);
        IERC20(wrappedGas).forceApprove(swapper, 0);
    }

    /// @inheritdoc StrategyAdapterHarvestable
    function _claim() internal override {
        address[] memory gauges = new address[](1);
        gauges[0] = gauge;
        sdAccountant.claim(gauges, new bytes[](1));

        if (rewards.length > 1) {
            address[] memory otherRewards = new address[](rewards.length - 1);
            for (uint i = 1; i < rewards.length; ++i) {
                otherRewards[i - 1] = rewards[i];
            }
            sdVault.claim(otherRewards, address(this));
        }
    }
}