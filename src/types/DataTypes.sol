// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

/// @notice Namespace for the structs used in `Multistrategy`
library MStrat {
    /// @notice Struct that contains a strategy data
    /// @param activation Block.timestamp of when the strategy was activated. 0 means not active
    /// @param debtRatio Maximum amount the strategy can borrow from the Multistrategy (in BPS of total assets in a Multistrategy)
    /// @param minDebtDelta Lower limit on the increase or decrease of debt since last harvest
    /// @param maxDebtDelta Upper limit on the increase or decrease of debt since last harvest
    /// @param totalDebt Total debt that this strategy has
    /// @param totalGain Total gains that this strategy has realized
    /// @param totalLoss Total losses that this strategy has realized
    struct StrategyParams {
        uint256 activation;
        uint256 debtRatio;
        uint256 minDebtDelta;
        uint256 maxDebtDelta;
        uint256 totalDebt;
        uint256 totalGain;
        uint256 totalLoss;
    }
}