// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

/// @title Errors
/// @notice Library containing all custom errors the protocol may revert with.
library Errors {
    /*//////////////////////////////////////////////////////////////////////////
                                      GENERICS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Thrown when `msg.sender` is not the manager.
    error CallerNotManager(address caller);

    /// @notice Thrown when `msg.sender` is not a guardian.
    error CallerNotGuardian(address caller);

    /// @notice Thrown when `amount` is zero.
    error ZeroAmount(uint256 amount);

    /// @notice Thrown when `currentBalance` is lower than `amount`.
    error InsufficientBalance(uint256 currentBalance, uint256 amount);

    /// @notice Thrown when `addr` is an unexpected address.
    error InvalidAddress(address addr);

    /*//////////////////////////////////////////////////////////////////////////
                                    MULTISTRATEGY
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Thrown when the caller is not an active strategy.
    error CallerNotStrategy(address caller);

    /// @notice Thrown when performing an action on a non-active strategy.
    error StrategyNotActive(address strategy);

    /// @notice Thrown when performing an action on an active strategy.
    error StrategyAlreadyActive(address strategy);

    /// @notice Thrown when strategies array length doesn't match MAXIMUM_STRATEGIES.
    error StrategiesLengthMissMatch();

    /// @notice Thrown when a strategy is reporting a gain and a loss simultaneously.
    error GainLossMissmatch();

    /// @notice Thrown when there is a duplicate strategy when trying to update the deposit or withdraw order.
    error DuplicateStrategyInArray();

    /// @notice Thrown when a deposit would exceed the depositLimit
    error DepositLimit();

    /// @notice Thrown when the owner tries to set a fee above the maximum permited fee.
    error ExcessiveFee(uint256 fee);

    /// @notice Thrown when the debtRatio of a strategy or a multistrategy is above 100%.
    error DebtRatioAboveMaximum(uint256 debtRatio);

    /// @notice Thrown when minDebtDelta is above maxDebtDelta or maxDebtDelta is below minDebtDelta.
    error InvalidDebtDelta();

    /// @notice Thrown when a strategy is reporting a loss higher than its total debt.
    error InvalidStrategyLoss();

    /// @notice Thrown when trying to add a new strategy to the multistrategy but it already reached the
    /// maximum amount of strategies.
    error MaximumAmountStrategies();

    /// @notice Thrown when trying to retire a strategy that already has a `debtRatio` of 0.
    error StrategyAlreadyRetired();

    /// @notice Thrown when it couldn't find a strategy
    error StrategyNotFound();

    /*//////////////////////////////////////////////////////////////////////////
                                STRATEGY WRAPPER
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Thrown when the caller is not the Multistrategy.
    error CallerNotMultistrategy(address caller);

    /// @notice Thrown when the `_depositToken` parameter on the constructor doesn't match 
    /// the `deposit` token on Multistrategy.
    error DepositTokenMissmatch(address multDepositToken, address stratDepositToken);
}