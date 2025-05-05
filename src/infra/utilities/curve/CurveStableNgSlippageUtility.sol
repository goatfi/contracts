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
    function getDepositSlippage(address _lp, int128 _assetIndex, uint256 _amount) external view returns (uint256 slippage, bool positive) {
        ICurveLiquidityPool curveLiquidityPool = ICurveLiquidityPool(_lp);
        uint256 nCoins = curveLiquidityPool.N_COINS();

        uint256[] memory amounts = new uint256[](nCoins);
        amounts[_assetIndex.toUint256()] = _amount;
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
    function getWithdrawSlippage(address _lp, int128 _assetIndex, uint256 _amount) external view returns (uint256 slippage, bool positive) {
        ICurveLiquidityPool curveLiquidityPool = ICurveLiquidityPool(_lp);
        uint256 nCoins = curveLiquidityPool.N_COINS();

        uint256[] memory amounts = new uint256[](nCoins);
        amounts[_assetIndex.toUint256()] = _amount;
        uint256 lpShares = curveLiquidityPool.calc_token_amount(amounts, false);
        uint256[] memory prices = curveLiquidityPool.stored_rates();
        uint256[] memory balancedAmounts = _getWithdrawBalancedAmounts(_lp, lpShares, nCoins);

        uint256 amount = curveLiquidityPool.calc_withdraw_one_coin(lpShares, _assetIndex);
        uint256 value = amount * prices[_assetIndex.toUint256()];
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

    /// @notice Calculates the balanced amounts to not get any slippage when removing liquidity from a Curve Liquidity Pool.
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