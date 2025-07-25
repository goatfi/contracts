// SPDX-License-Identifier: GNU AGPLv3

pragma solidity 0.8.27;

import { IERC20, SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { StrategyAdapterHarvestable } from "src/abstracts/StrategyAdapterHarvestable.sol";
import { CurveLPBase } from "src/abstracts/CurveLPBase.sol";
import { ICurveVaultXChain } from "interfaces/stakedao/ICurveVaultXChain.sol";
import { IClaimRewardsXChain } from "interfaces/stakedao/IClaimRewardsXChain.sol";
import { IMultistrategy } from "interfaces/infra/multistrategy/IMultistrategy.sol";
import { MStrat } from "src/types/DataTypes.sol";
import { Errors } from "src/infra/libraries/Errors.sol";

contract CurveStableNgSDAdapter is StrategyAdapterHarvestable, CurveLPBase {
    using SafeERC20 for IERC20;
    using Math for uint256;

    /// @notice Struct containing the needed addresses for this adapter.
    struct CurveSNGSDData {
        address curveLiquidityPool;
        address sdVault;
        address sdRewards;
        address curveSlippageUtility;
        uint256 assetIndex;
    }

    /// @notice The StakeDAO Vault where Curve Liquidity Pool shares will be deposited to earn rewards.
    ICurveVaultXChain public immutable stakeDAOVault;

    /// @notice The StakeDAO Claim rewards contract.
    IClaimRewardsXChain public immutable stakeDAORewards;

    /// @notice Address of the StakeDAO Vault Gauge
    address public immutable gauge;

    /// @notice Index of the asset in the coins array casted to int128.
    int128 public immutable assetIndex128;

    /// @notice Number of different coins in coins array.
    uint256 public immutable nCoins;

    /// @notice Constructor for the strategy adapter.
    /// @param _multistrategy The address of the multi-strategy contract.
    /// @param _asset The address of the asset.
    /// @param _harvestAddresses Struct of Protocol Addresses.
    /// @param _curveLPSDData Struct of Curve and StakeDAO Data.
    /// @param _name The name of this Strategy Adapter.
    /// @param _id The type identifier of this Strategy Adapter.
    constructor(
        address _multistrategy,
        address _asset,
        HarvestAddresses memory _harvestAddresses,
        CurveSNGSDData memory _curveLPSDData,
        string memory _name,
        string memory _id
    ) 
        StrategyAdapterHarvestable(_multistrategy, _asset, _harvestAddresses,_name, _id)
        CurveLPBase(_curveLPSDData.curveLiquidityPool, _curveLPSDData.curveSlippageUtility)
    {   
        stakeDAOVault = ICurveVaultXChain(_curveLPSDData.sdVault);
        stakeDAORewards = IClaimRewardsXChain(_curveLPSDData.sdRewards);
        assetIndex = _curveLPSDData.assetIndex;
        assetIndex128 = int128(uint128(assetIndex));
        nCoins = curveLiquidityPool.N_COINS();
        gauge = stakeDAOVault.sdGauge();
        withdrawBuffer = PPM_DENOMINATOR + 1;
        _giveAllowances();
    }

    /*//////////////////////////////////////////////////////////////////////////
                            INTERNAL CONSTANT FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Returns the total amount of assets held in this adapter.
    /// @return The total amount of assets held by this adapter.
    function _totalAssets() internal override view returns(uint256) {
        uint256 vaultShares = IERC20(gauge).balanceOf(address(this));

        if(vaultShares == 0) return _balance();

        uint256 assetsWithdrawable = curveLiquidityPool.calc_withdraw_one_coin(vaultShares, assetIndex128);
        return assetsWithdrawable + _balance();
    }

    /// @inheritdoc StrategyAdapterHarvestable
    function _verifyRewardToken(address _token) internal view override {
        require(
            _token != address(curveLiquidityPool) &&
            _token != address(stakeDAOVault) && 
            _token != address(stakeDAORewards) &&
            _token != address(gauge),
            Errors.InvalidRewardToken(_token));
    }

    /*//////////////////////////////////////////////////////////////////////////
                            INTERNAL NON-CONSTANT FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Deposits all the available base asset balance.
    function _deposit() internal override {
        uint256 balance = _balance();
        (uint256 slippage, bool positiveSlippage) = getDepositSlippage(balance);
        require(positiveSlippage || slippage <= curveSlippageLimit, CurveSlippageTooHigh(slippage, curveSlippageLimit));

        uint256[] memory amounts = new uint256[](nCoins);
        amounts[assetIndex] = balance;
        uint256 lpSharesAmount = curveLiquidityPool.add_liquidity(amounts, 0);
        stakeDAOVault.deposit(address(this), lpSharesAmount);
    }

    /// @notice Withdraws a specified amount of assets.
    /// @param _amount The amount of assets to withdraw.
    function _withdraw(uint256 _amount) internal override {
        (uint256 slippage, bool positiveSlippage) = getWithdrawSlippage(_amount);
        require(positiveSlippage || slippage <= curveSlippageLimit, CurveSlippageTooHigh(slippage, curveSlippageLimit));

        uint256[] memory amounts = new uint256[](nCoins);
        amounts[assetIndex] = _amount;
        uint256 lpSharesNeeded = curveLiquidityPool.calc_token_amount(amounts, false);
        uint256 lpSharesBalance = IERC20(gauge).balanceOf(address(this));

        lpSharesNeeded = _amount >= _getMinDebtDelta() ? lpSharesNeeded.mulDiv(withdrawBuffer, PPM_DENOMINATOR) : lpSharesNeeded *= 2;

        uint256 lpShares = lpSharesNeeded.min(lpSharesBalance);
        stakeDAOVault.withdraw(lpShares);
        if(lpSharesNeeded > lpSharesBalance) {
            curveLiquidityPool.remove_liquidity_one_coin(lpShares, assetIndex128, 0);
        } else {
            curveLiquidityPool.remove_liquidity_one_coin(lpShares, assetIndex128, _amount);
        }
    }

    /// @notice Performs an emergency withdrawal of all assets from StakeDAO and Curve.
    /// This function is intended for emergency situations where all assets need to be withdrawn immediately.
    /// @dev The other non-asset tokens will be sent to the owner of this contract.
    function _emergencyWithdraw() internal override {
        stakeDAOVault.withdrawAll();
        uint256 lpShares = curveLiquidityPool.balanceOf(address(this));

        if(lpShares > 0) {
            uint256[] memory minAmounts = new uint256[](nCoins);
            curveLiquidityPool.remove_liquidity(lpShares, minAmounts);
        }

        for(uint256 i = 0; i < nCoins; ++i) {
            address token = curveLiquidityPool.coins(i);
            if (token != asset) {
                uint256 tokenBalance = IERC20(token).balanceOf(address(this));
                IERC20(token).safeTransfer(owner(), tokenBalance);
            }
        }
    }

    /// @notice Sets the maximum allowance of the base asset for the Curve Liquidity Pool.
    /// and sets the maximum allowance of Curve Liquidity Pool shares for StakeDAO
    function _giveAllowances() internal override {
        IERC20(asset).forceApprove(address(curveLiquidityPool), type(uint).max);
        IERC20(curveLiquidityPool).forceApprove(address(stakeDAOVault), type(uint).max);
        IERC20(wrappedGas).forceApprove(swapper, type(uint).max);
    }

    /// @notice Revokes all the allowances.
    function _revokeAllowances() internal override {
        IERC20(asset).forceApprove(address(curveLiquidityPool), 0);
        IERC20(curveLiquidityPool).forceApprove(address(stakeDAOVault), 0);
        IERC20(wrappedGas).forceApprove(swapper, 0);
    }

    /// @inheritdoc StrategyAdapterHarvestable
    function _claim() internal override {
        address[] memory gauges = new address[](1);
        gauges[0] = gauge;
        stakeDAORewards.claimRewards(gauges);
    }

    /// @notice Gets the minimum debt delta of this adapter.
    /// @return minDebtDelta This adapter's minimum debt delta.
    function _getMinDebtDelta() internal view returns (uint256 minDebtDelta) {
        MStrat.StrategyParams memory params = IMultistrategy(multistrategy).getStrategyParameters(address(this));
        minDebtDelta = params.minDebtDelta;
    }
}