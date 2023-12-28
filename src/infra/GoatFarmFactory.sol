// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import { GoatFarm } from "./GoatFarm.sol";
import { IGoatFarmFactory } from "../interfaces/infra/IGoatFarmFactory.sol";

contract GoatFarmFactory is IGoatFarmFactory {
    event FarmDeployed(address indexed farm);

    function createFarm(address stakedToken, address rewardToken, uint256 duration_in_sec) external returns (address) {
        GoatFarm farm = new GoatFarm();
        farm.initialize(stakedToken, rewardToken, duration_in_sec, msg.sender);
        emit FarmDeployed(address(farm));
        return address(farm);
    }
}
