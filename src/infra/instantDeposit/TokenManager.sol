// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import { SafeERC20, IERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IInstantDepositRouter } from "interfaces/infra/instantDeposit/IInstantDepositRouter.sol";
import { InstantDepositErrors } from "./InstantDepositErrors.sol";

/**
 * @title Token manager
 * @author kexley, Beefy
 * @notice Token manager handles the token approvals for the instant deposit router
 * @dev Users should approve this contract instead of the instant deposit router to handle the input ERC20 tokens
 */
contract TokenManager is InstantDepositErrors {
    using SafeERC20 for IERC20;

    /**
     * @notice Instant deposit router immutable address
     */
    address public immutable instantDeposit;

    /**
     * @dev This contract is created in the constructor of the instant deposit router
     */
    constructor() {
        instantDeposit = msg.sender;
    }

    /**
     * @notice Pulls tokens from a user and transfers them directly to the instant deposit router
     * @dev Only the token owner can call this function indirectly via the instant deposit router
     * @param _user Address to pull tokens from
     * @param _inputs Token addresses and amounts to pull
     */
    function pullTokens(address _user, IInstantDepositRouter.Input[] calldata _inputs) external {
        if (msg.sender != instantDeposit) revert CallerNotInstantDeposit(msg.sender);
        uint256 inputLength = _inputs.length;
        for (uint256 i; i < inputLength;) {
            IInstantDepositRouter.Input calldata input = _inputs[i];
            unchecked {
                ++i;
            }

            if (input.token == address(0)) continue;
            IERC20(input.token).safeTransferFrom(_user, msg.sender, input.amount);
        }
    }
}
