// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

interface IAccountant {
    function claim(address[] calldata _gauges, bytes[] calldata harvestData) external;
    function getPendingRewards(address _vault, address _account) external view returns (uint256);
    function REWARD_TOKEN() external view returns (address);
}