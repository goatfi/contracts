// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IGoatFarmFactory {
    function createFarm(address stakedToken, address rewardToken, uint256 duration_in_sec) external returns (address);
}
