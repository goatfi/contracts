// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import { GoatFarmTestBase } from "../GoatFarmBase.t.sol";
import { GoatFarmHandler } from "./GoatFarmHandler.sol";
import { GoatFarmActorManager } from "./GoatFarmActorManager.sol";
import { TimestampStore } from "../../stores/TimestampStore.sol";

contract GoatFarmInvariant is GoatFarmTestBase {

    GoatFarmHandler[] private handlers;
    GoatFarmActorManager private manager;
    TimestampStore private timestampStore;

    function setUp() public override{
        GoatFarmTestBase.setUp();
        timestampStore = new TimestampStore();

        //Handlers[0] will be treated as the treasury. Set it as notifier and transfer all rewards so it can notify the farms.
        handlers.push(new GoatFarmHandler(farm, stakedToken, rewardToken, timestampStore));
        farm.setNotifier(address(handlers[0]), true);

        vm.startPrank(TREASURY);
        rewardToken.transfer(address(handlers[0]), rewardToken.totalSupply());
        vm.stopPrank();

        //Start at i = 1 due to the treasury being at index 0
        for (uint256 i = 1; i < 4; i++) {
            handlers.push(new GoatFarmHandler(farm, stakedToken, rewardToken, timestampStore));
            stakedToken.transfer(address(handlers[i]), 10 ether);
        }

        manager = new GoatFarmActorManager(handlers, farm, stakedToken, rewardToken);
        targetContract(address(manager));
    }

    function invariant_StakedBalance() public {
        uint256 totalStaked;
        for (uint256 i = 0; i < handlers.length; i++) {
            totalStaked += farm.balanceOf(address(handlers[i]));
        }

        assertEq(farm.totalSupply(), totalStaked);
    }

    function invariant_RewardsBalance() public {
        uint256 treasuryBalance = rewardToken.balanceOf(address(handlers[0]));
        uint256 contractBalance = rewardToken.balanceOf(address(farm));
        uint256 totalClaimed;
        for (uint256 i = 1; i < 4; i++) {
            totalClaimed += rewardToken.balanceOf(address(handlers[i]));
        }

        assertEq(treasuryBalance + contractBalance + totalClaimed, rewardToken.totalSupply());
    }
}
