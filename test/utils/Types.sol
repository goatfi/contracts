// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

struct Users {
    // Default owner for all Goat Protocol contracts.
    address payable owner;
    // Default keeper for all Goat Protocol contracts.
    address payable keeper;
    // Default guardian of the Multistrategy contracts.
    address payable guardian;
    // Default fee recipient of Goat Protocol
    address payable feeRecipient;
    // Impartial user1.
    address payable alice;
    // Impartial user2.
    address payable bob;
}
