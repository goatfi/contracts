// SPDX-License-Identifier: GNU AGPLv3
pragma solidity 0.8.27;

/// @title ICurveSlippageUtility
/// @notice Interface for calculating expected slippage on Curve LP deposits and withdrawals.
/// @dev Slippage values are represented as 1e18-scaled decimals (1e18 = 100%).
interface ICurveSlippageUtility {
    /**
     * @notice Calculates the slippage incurred when depositing a specific asset into a Curve LP.
     * @param _lp The address of the Curve liquidity pool.
     * @param _assetIndex The index of the asset in the pool being deposited.
     * @param _amount The amount of the asset being deposited.
     * @return slippage The estimated slippage, scaled by 1e18 (1e18 = 100%).
     * @return positive Indicates whether the slippage is positive (true) or negative (false).
     */
    function getDepositSlippage(
        address _lp,
        int128 _assetIndex,
        uint256 _amount
    ) external view returns (uint256 slippage, bool positive);

    /**
     * @notice Calculates the slippage incurred when withdrawing a specific asset from a Curve LP.
     * @param _lp The address of the Curve liquidity pool.
     * @param _assetIndex The index of the asset in the pool being withdrawn.
     * @param _amount The amount of the asset being withdrawn.
     * @return slippage The estimated slippage, scaled by 1e18 (1e18 = 100%).
     * @return positive Indicates whether the slippage is positive (true) or negative (false).
     */
    function getWithdrawSlippage(
        address _lp,
        int128 _assetIndex,
        uint256 _amount
    ) external view returns (uint256 slippage, bool positive);
}
