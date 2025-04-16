// SPDX-License-Identifier: GNU AGPLv3

pragma solidity 0.8.27;

import { IERC20, SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { ICurveVaultXChain } from "interfaces/stakedao/ICurveVaultXChain.sol";
import { IClaimRewardsXChain } from "interfaces/stakedao/IClaimRewardsXChain.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { StrategyAdapterHarvestable } from "src/abstracts/StrategyAdapterHarvestable.sol";
import { ICurveLiquidityPool } from "interfaces/curve/ICurveLiquidityPool.sol";
import { Errors } from "src/infra/libraries/Errors.sol";

contract CurveStableNgSDAdapter is StrategyAdapterHarvestable {
    using SafeERC20 for IERC20;
    using SafeCast for int128;
    using Math for uint256;

    struct CurveSNGSDData {
        address curveLiquidityPool;
        address sdVault;
        address sdRewards;
        int128 assetIndex;
    }

    /// @notice The Curve Liquidity Pool where the asset will be deposited.
    ICurveLiquidityPool curveLiquidityPool;

    /// @notice The StakeDAO Vault where Curve Liquidity Pool shares will be deposited to earn rewards.
    ICurveVaultXChain public immutable stakeDAOVault;

    /// @notice The StakeDAO Claim rewards contract.
    IClaimRewardsXChain public immutable stakeDAORewards;

    /// @notice Address of the StakeDAO Vault Gauge
    address public immutable gauge;

    /// @notice Index of the asset in the coins array.
    int128 public immutable assetIndex;

    /// @notice Number of different coins in coins array.
    uint256 public immutable nCoins;

    /// @notice Slippage limit when withdrawing from the Curve Liquidity Pool.
    /// @dev If the slippage is higher than this parameter, the transaction will revert.
    uint256 public curveSlippageLimit;

    /// @notice Thrown when the withdraw slippage
    /// @param slippage Expected slippage
    /// @param slippageLimit Slippage limit
    error CurveSlippageTooHigh(uint256 slippage, uint256 slippageLimit);

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
    {   
        curveLiquidityPool = ICurveLiquidityPool(_curveLPSDData.curveLiquidityPool);
        stakeDAOVault = ICurveVaultXChain(_curveLPSDData.sdVault);
        stakeDAORewards = IClaimRewardsXChain(_curveLPSDData.sdRewards);
        assetIndex = _curveLPSDData.assetIndex;
        nCoins = curveLiquidityPool.N_COINS();
        gauge = stakeDAOVault.sdGauge();
        _giveAllowances();
    }
    /*//////////////////////////////////////////////////////////////////////////
                            USER-FACING CONSTANT FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    function getDepositSlippage(uint256 _amount) external view returns (uint256 slippage, bool positive) {
        return _getDepositSlippage(_amount);
    }

    function getWithdrawSlippage(uint256 _amount) external view returns (uint256 slippage, bool positive) {
        return _getWithdrawSlippage(_amount);
    }

    /*//////////////////////////////////////////////////////////////////////////
                            INTERNAL CONSTANT FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Returns the total amount of assets held in this adapter.
    function _totalAssets() internal override view returns(uint256) {
        uint256 vaultShares = IERC20(gauge).balanceOf(address(this));
        uint256 assetsWithdrawable = curveLiquidityPool.calc_withdraw_one_coin(vaultShares, assetIndex);
        uint256 assetBalance = IERC20(asset).balanceOf(address(this));

        return assetsWithdrawable + assetBalance;
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

    /// @notice Calculates the slippage when adding liquidity to a Curve Liquidity Pool.
    function _getDepositSlippage(uint256 _amount) internal view returns (uint256 slippage, bool positive) {
        uint256[] memory amounts = new uint256[](nCoins);
        amounts[assetIndex.toUint256()] = _amount;
        uint256[] memory prices = curveLiquidityPool.stored_rates();
        uint256[] memory balances = curveLiquidityPool.get_balances();
        uint256[] memory balancedAmounts = _getDepositBalancedAmounts(amounts, prices, balances);
        
        uint256 lpSharesExpected = curveLiquidityPool.calc_token_amount(amounts, true);
        uint256 lpSharesBalancedExpected = curveLiquidityPool.calc_token_amount(balancedAmounts, true);

        slippage = (
            lpSharesExpected > lpSharesBalancedExpected
                ? (lpSharesExpected - lpSharesBalancedExpected).mulDiv(1 ether, lpSharesBalancedExpected)
                : (lpSharesBalancedExpected - lpSharesExpected).mulDiv(1 ether, lpSharesBalancedExpected)
        );
        positive = lpSharesExpected >= lpSharesBalancedExpected;
    }

    /// @notice Calculates the slippage when removing liquidity from a Curve Liquidity Pool with one coin.
    function _getWithdrawSlippage(uint256 _amount) internal view returns (uint256 slippage, bool positive) {
        uint256[] memory amounts = new uint256[](nCoins);
        amounts[assetIndex.toUint256()] = _amount;
        uint256 lpShares = curveLiquidityPool.calc_token_amount(amounts, false);
        uint256[] memory prices = curveLiquidityPool.stored_rates();
        uint256[] memory balancedAmounts = _getWithdrawBalancedAmounts(lpShares);

        uint256 amount = curveLiquidityPool.calc_withdraw_one_coin(lpShares, assetIndex);
        uint256 value = amount * prices[assetIndex.toUint256()];
        uint256 balancedValue = 0;

        for (uint256 i = 0; i < nCoins; i++) {
            balancedValue += prices[i] * balancedAmounts[i];
        }

        slippage = (
            value > balancedValue
                ? (value - balancedValue).mulDiv(1 ether, balancedValue)
                : (balancedValue - value).mulDiv(1 ether, balancedValue)
        );
        positive = value >= balancedValue;
    }

    /// @notice Calculates the balanced amounts to not get any slippage when adding liquidity on a Curve Liquidity Pool
    function _getDepositBalancedAmounts(
        uint256[] memory _amounts, 
        uint256[] memory _prices, 
        uint256[] memory _balances
    ) internal view returns (uint256[] memory) {
        uint256 totalValue;
        uint256 totalBalances;
        uint256[] memory ratios = new uint256[](nCoins);
        uint256[] memory balancedAmounts = new uint256[](nCoins);

        for(uint256 i = 0; i < nCoins; ++i) {
            totalValue += _amounts[i] * _prices[i];
            totalBalances += _balances[i];
        }
        for(uint256 i = 0; i < nCoins; ++i) {
            ratios[i] = _balances[i].mulDiv(1e18, totalBalances);
        }
        for(uint256 i = 0; i < nCoins; ++i) {
            uint256 denominator;
            for(uint256 j = 0; j < nCoins; ++j) {
                denominator += ratios[j].mulDiv(_prices[j], ratios[i]);
            }
            balancedAmounts[i] = totalValue / denominator;
        }
        return balancedAmounts;
    }

    /// @notice Calculates the balanced amounts to not get any slippage when removing liquidity from a Curve Liquidity Pool.
    function _getWithdrawBalancedAmounts(uint256 _lpTokenAmount) internal view returns (uint256[] memory) {
        uint256 totalSupply = curveLiquidityPool.totalSupply();
        uint256[] memory balances = curveLiquidityPool.get_balances();
        uint256[] memory balancedAmounts = new uint256[](nCoins);

        for(uint256 i = 0; i < nCoins; ++i) {
            balancedAmounts[i] = balances[i].mulDiv(_lpTokenAmount, totalSupply);
        }
        return balancedAmounts;
    }

    /*//////////////////////////////////////////////////////////////////////////
                        USER FACING NON-CONSTANT FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    function setCurveSlippageLimit(uint256 _slippageLimit) external onlyOwner {
        require(_slippageLimit <= 100 ether, Errors.SlippageLimitExceeded(_slippageLimit));
        curveSlippageLimit = _slippageLimit;
    }

    /*//////////////////////////////////////////////////////////////////////////
                            INTERNAL NON-CONSTANT FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Deposits all the available base asset balance.
    function _deposit() internal override {
        uint256[] memory amounts = new uint256[](nCoins);
        uint256 balance = IERC20(asset).balanceOf(address(this));
        amounts[assetIndex.toUint256()] = balance;
        uint256 lpSharesAmount = curveLiquidityPool.add_liquidity(amounts, type(uint256).max);
        stakeDAOVault.deposit(address(this), lpSharesAmount);
    }

    /// @notice Withdraws a specified amount of assets.
    /// @param _amount The amount of assets to withdraw.
    function _withdraw(uint256 _amount) internal override {
        (uint256 slippage, bool positiveSlippage) = _getWithdrawSlippage(_amount);
        require(positiveSlippage || slippage <= curveSlippageLimit, CurveSlippageTooHigh(slippage, curveSlippageLimit));

        uint256[] memory amounts = new uint256[](nCoins);
        amounts[assetIndex.toUint256()] = _amount;
        uint256 lpSharesNeeded = curveLiquidityPool.calc_token_amount(amounts, false);
        uint256 lpSharesBalance = IERC20(gauge).balanceOf(address(this));
        uint256 lpShares = Math.min(lpSharesNeeded, lpSharesBalance);
        stakeDAOVault.withdraw(lpShares);
        curveLiquidityPool.remove_liquidity_one_coin(lpShares, assetIndex, _amount);
    }

    /// @notice Performs an emergency withdrawal of all assets from StakeDAO and Curve.
    /// This function is intended for emergency situations where all assets need to be withdrawn immediately.
    /// @dev The other non-asset tokens will be sent to the owner of this contract.
    function _emergencyWithdraw() internal override {
        stakeDAOVault.withdrawAll();
        uint256 lpSharesAmount = curveLiquidityPool.balanceOf(address(this));
        uint256[] memory minAmounts = new uint256[](nCoins);
        curveLiquidityPool.remove_liquidity(lpSharesAmount, minAmounts);

        for(uint256 i = 0; i < nCoins; ++i) {
            address token = curveLiquidityPool.coins(i);
            if (token != asset) {
                uint256 tokenBalance = IERC20(token).balanceOf(address(this));
                IERC20(token).transfer(owner(), tokenBalance);
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
}