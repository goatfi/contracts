// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IMerklDistributor {
    function toggleOperator(address user, address operator) external;
}