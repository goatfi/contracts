// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { IStrategy } from "interfaces/infra/IStrategy.sol";

/**
 * @title GoatVault Interface
 * @dev Interface for the GoatVault contract to deposit funds for yield optimizing.
 */
interface IGoatVault {

    /**
     * @dev Struct to hold strategy candidate information.
     */
    struct StratCandidate {
        address implementation;
        uint proposedTime;
    }

    /**
     * @dev Sets the initial values for the vault.
     * @param _strategy The address of the strategy.
     * @param _name The name of the vault token.
     * @param _symbol The symbol of the vault token.
     * @param _approvalDelay The delay before a new strategy can be approved.
     */
    function initialize(
        IStrategy _strategy,
        string memory _name,
        string memory _symbol,
        uint256 _approvalDelay
    ) external;

    /**
     * @dev Returns the underlying ERC20 token of the vault.
     * @return The IERC20 token interface.
     */
    function want() external view returns (IERC20);

    /**
     * @dev Calculates the total underlying value of the token held by the system.
     * @return The total underlying value.
     */
    function balance() external view returns (uint);

    /**
     * @dev Returns the amount of tokens available for borrowing.
     * @return The amount of tokens available.
     */
    function available() external view returns (uint256);

    /**
     * @dev Returns the current value of one vault share in terms of the underlying asset.
     * @return The value of one vault share.
     */
    function getPricePerFullShare() external view returns (uint256);

    /**
     * @dev Deposits all of the sender's funds into the vault.
     */
    function depositAll() external;

    /**
     * @dev Deposits a specified amount of funds into the vault.
     * @param _amount The amount of funds to deposit.
     */
    function deposit(uint _amount) external;

    /**
     * @dev Sends funds into the strategy to start earning yield.
     */
    function earn() external;

    /**
     * @dev Withdraws all of the sender's funds from the vault.
     */
    function withdrawAll() external;

    /**
     * @dev Withdraws a specified amount of funds from the vault.
     * @param _shares The amount of shares to withdraw.
     */
    function withdraw(uint256 _shares) external;

    /**
     * @dev Proposes a new strategy for the vault.
     * @param _implementation The address of the candidate strategy.
     */
    function proposeStrat(address _implementation) external;

    /**
     * @dev Upgrades to the proposed strategy after the approval delay has passed.
     */
    function upgradeStrat() external;

    /**
     * @dev Rescues funds stuck in the vault that the strategy can't handle.
     * @param _token The address of the token to rescue.
     */
    function inCaseTokensGetStuck(address _token) external;
}