// SPDX-License-Identifier: GNU AGPLv3

pragma solidity >=0.8.20 <= 0.9.0;

interface IOwnable {
    function transferOwnership(address newOwner) external;
}

interface IStrategyAdapterMock {
    function earn(uint256 _amount) external;
    function lose(uint256 _amount) external;
    function stakingBalance() external view returns(uint256);
}