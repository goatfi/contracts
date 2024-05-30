// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

struct Users {
    // Default owner for all GoatFi contracts.
    address payable owner;
    // Default keeper for all GoatFi contracts.
    address payable keeper;
    // Impartial user1.
    address payable alice;
    // Impartial user2.
    address payable bob;
}
