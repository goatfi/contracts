// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

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

    /// @notice Thrown when `amount` is higher than caller's balance.
    error InsufficientBalance(uint256 callerBalance, uint256 amount);

    /*//////////////////////////////////////////////////////////////////////////
                                    MULTISTRATEGY
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Thrown when trying to set the debt ratio above 100% (10_000 BPS)
    error DebtRatioHigherThanMax(uint256 debtRatio);

    /// @notice Thrown when the recipient of a deposit is `address(0)` or the multistrategy contract.
    error InvalidDepositRecipient();

    /// @notice Thrown when strategies array length doesn't match MAXIMUM_STRATEGIES
    error StrategiesLengthMissMatch();

    /// @notice Thrown when performing an action on a non-active strategy
    error StrategyNotActive();

    /// @notice Thrown when there is a duplicate strategy when trying to update the deposit or withdraw order.
    error DuplicateStrategyInArray();

    /// @notice Thrown when a deposit would exceed the depositLimit
    error DepositLimit();
}