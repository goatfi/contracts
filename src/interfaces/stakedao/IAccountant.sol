// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

interface IAccountant {
    function totalSupply(address asset) external view returns (uint128);
    function balanceOf(address asset, address account) external view returns (uint128);
    function claim(address[] calldata _gauges, bytes[] calldata harvestData) external;
    function REWARD_TOKEN() external view returns (address);
}