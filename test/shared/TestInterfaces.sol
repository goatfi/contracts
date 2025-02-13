// SPDX-License-Identifier: GNU AGPLv3

pragma solidity >=0.8.20 <= 0.9.0;

interface IOwnable {
    function transferOwnership(address newOwner) external;
}

interface IPausable {
    function paused() external view returns(bool);
}