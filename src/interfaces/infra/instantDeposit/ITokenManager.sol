// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import { IInstantDepositRouter } from "./IInstantDepositRouter.sol";

/**
 * @title Token manager interface
 * @author kexley, Beefy
 * @notice Interface for the token manager
 */
interface ITokenManager {
    /**
     * @notice Pull tokens from a user
     * @param _user Address of user to transfer tokens from
     * @param _inputs Addresses and amounts of tokens to transfer
     */
    function pullTokens(address _user, IInstantDepositRouter.Input[] calldata _inputs) external;
}
