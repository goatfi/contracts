// SPDX-License-Identifier: GNU AGPLv3

pragma solidity 0.8.27;

import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { ICurveSlippageUtility } from "interfaces/infra/utilities/curve/ICurveSlippageUtility.sol";
import { ICurveLiquidityPool } from "interfaces/curve/ICurveLiquidityPool.sol";

contract CurveStableNgSlippageUtility is ICurveSlippageUtility {
    using SafeCast for int128;
    using Math for uint256;

    /// @notice Calculates the slippage when adding liquidity to a Curve Liquidity Pool.
    /// @param _lp Address of the Curve Liquidity Pool.
    /// @param _assetIndex Index of the asset in the coins array.
    /// @param _amount The amount of tokens that will be deposited.
    /// @return slippage The calculated deposit slippage where 1e18 = 100%.
    /// @return positive Indicates whether the slippage is positive (true) or negative (false).
    function getDepositSlippage(address _lp, uint256 _assetIndex, uint256 _amount) external view returns (uint256 slippage, bool positive) {
        ICurveLiquidityPool curveLiquidityPool = ICurveLiquidityPool(_lp);
        uint256 nCoins = curveLiquidityPool.N_COINS();

        uint256[] memory amounts = new uint256[](nCoins);
        amounts[_assetIndex] = _amount;
        uint256[] memory prices = curveLiquidityPool.stored_rates();
        uint256[] memory balances = curveLiquidityPool.get_balances();
        uint256[] memory balancedAmounts = _getDepositBalancedAmounts(amounts, prices, balances, nCoins);
        
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
    /// @param _lp Address of the Curve Liquidity Pool.
    /// @param _assetIndex Index of the asset in the coins array.
    /// @param _amount The amount of tokens that will be withdrawn.
    /// @return slippage The calculated withdraw slippage where 1e18 = 100%.
    /// @return positive Indicates whether the slippage is positive (true) or negative (false).
    function getWithdrawSlippage(address _lp, uint256 _assetIndex, uint256 _amount) external view returns (uint256 slippage, bool positive) {
        ICurveLiquidityPool curveLiquidityPool = ICurveLiquidityPool(_lp);
        uint256 nCoins = curveLiquidityPool.N_COINS();

        uint256[] memory amounts = new uint256[](nCoins);
        amounts[_assetIndex] = _amount;
        uint256 lpShares = curveLiquidityPool.calc_token_amount(amounts, false);
        uint256[] memory prices = curveLiquidityPool.stored_rates();
        uint256[] memory balancedAmounts = _getWithdrawBalancedAmounts(_lp, lpShares, nCoins);

        uint256 amount = curveLiquidityPool.calc_withdraw_one_coin(lpShares, int128(uint128(_assetIndex)));
        uint256 value = amount * prices[_assetIndex];
        uint256 balancedValue = 0;

        for (uint256 i = 0; i < nCoins; i++) {
            balancedValue += prices[i] * balancedAmounts[i];
        }

        if(balancedValue > 0) {
            slippage = (
            value > balancedValue
                ? (value - balancedValue).mulDiv(1 ether, balancedValue)
                : (balancedValue - value).mulDiv(1 ether, balancedValue)
            );
            positive = value >= balancedValue;
        } else {
            slippage = 0;
            positive = true;
        }
    }

    /// @notice Calculates the balanced amounts to avoid slippage when adding liquidity to a Curve StableSwapNG pool.
    /// @param _amounts The amounts of each token the user intends to deposit.
    /// @param _prices The current price of each token.
    /// @param _balances The current balance of each token in the pool.
    /// @param _nCoins The total number of different tokens in the pool.
    /// @return balancedAmounts An array of token amounts adjusted to the pool's balance.
    function _getDepositBalancedAmounts(
        uint256[] memory _amounts, 
        uint256[] memory _prices, 
        uint256[] memory _balances,
        uint256 _nCoins
    ) internal pure returns (uint256[] memory) {
        uint256 totalValue;
        uint256 totalBalances;
        uint256[] memory ratios = new uint256[](_nCoins);
        uint256[] memory balancedAmounts = new uint256[](_nCoins);

        for(uint256 i = 0; i < _nCoins; ++i) {
            totalValue += _amounts[i] * _prices[i];
            totalBalances += _balances[i];
        }
        for(uint256 i = 0; i < _nCoins; ++i) {
            ratios[i] = _balances[i].mulDiv(1e18, totalBalances);
        }
        for(uint256 i = 0; i < _nCoins; ++i) {
            uint256 denominator;
            for(uint256 j = 0; j < _nCoins; ++j) {
                denominator += ratios[j].mulDiv(_prices[j], ratios[i]);
            }
            balancedAmounts[i] = totalValue / denominator;
        }
        return balancedAmounts;
    }

    /// @notice Calculates the proportional amounts of each token to withdraw from a Curve StableSwapNG pool based on a specified amount of LP tokens.
    /// @dev This function computes the user's share of each underlying token in the pool, proportional to their LP token holdings.
    /// @param _lp The address of the Curve StableSwapNG liquidity pool contract.
    /// @param _lpTokenAmount The amount of LP tokens the user intends to redeem.
    /// @param _nCoins The total number of different tokens in the pool.
    /// @return balancedAmounts An array containing the amounts of each token to withdraw.
    function _getWithdrawBalancedAmounts(
        address _lp,
        uint256 _lpTokenAmount,
        uint256 _nCoins
    ) internal view returns (uint256[] memory) {
        ICurveLiquidityPool curveLiquidityPool = ICurveLiquidityPool(_lp);
        uint256 totalSupply = curveLiquidityPool.totalSupply();
        uint256[] memory balances = curveLiquidityPool.get_balances();
        uint256[] memory balancedAmounts = new uint256[](_nCoins);

        for(uint256 i = 0; i < _nCoins; ++i) {
            balancedAmounts[i] = balances[i].mulDiv(_lpTokenAmount, totalSupply);
        }
        return balancedAmounts;
    }
}