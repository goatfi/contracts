// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

/**
 * @title Instand Deposit Errors
 * @author kexley, Beefy.
 * @notice Custom errors for instant deposit router
 */
contract InstantDepositErrors {
    error InvalidCaller(address owner, address caller);
    error TargetingInvalidContract(address target);
    error CallFailed(address target, uint256 value, bytes callData);
    error Slippage(address token, uint256 minAmountOut, uint256 balance);
    error EtherTransferFailed(address recipient);
    error CallerNotInstantDeposit(address caller);
    error InsufficientRelayValue(uint256 balance, uint256 relayValue);
}
