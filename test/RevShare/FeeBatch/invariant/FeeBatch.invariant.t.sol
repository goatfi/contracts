// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import { RevenueShareTestBase } from "../../RevenueShareBase.t.sol";
import { FeeBatchHandler } from "./FeeBatchHandler.sol";
import { FeeBatchActorManager } from "./FeeBatchActorManager.sol";
import { TimestampStore } from "../../../stores/TimestampStore.sol";

contract FeeBatchInvariant is RevenueShareTestBase {

    FeeBatchHandler[] private handlers;
    FeeBatchActorManager private manager;
    TimestampStore private timestampStore;

    uint256 handlerAmount = 5;

    function setUp() public override{
        RevenueShareTestBase.setUp();
        timestampStore = new TimestampStore();

        //Handlers[0] will be treated as the owner.
        handlers.push(new FeeBatchHandler(feeBatch, weth, timestampStore));

        feeBatch.setHarvesterConfig(HARVESTER, 0.01 ether);
        feeBatch.transferOwnership(address(handlers[0]));

        //Start at i = 1 due to the owner being at index 0
        for (uint256 i = 1; i < handlerAmount; i++) {
            handlers.push(new FeeBatchHandler(feeBatch, weth, timestampStore));
        }

        manager = new FeeBatchActorManager(handlers, feeBatch, weth, HARVESTER);
        targetContract(address(manager));
    }

    /// @notice All revenue must be distributed between the Reward Pool, FeeBatch and
    function invariant_RevenueBalance() public {
        uint256 rewardPoolBalance = weth.balanceOf(address(rewardPool));
        uint256 feeBatchBalance = weth.balanceOf(address(feeBatch));
        uint256 treasuryBalance = weth.balanceOf(TREASURY);
        uint256 harvesterBalance = HARVESTER.balance;

        uint256 totalRevenueGenerated = 0;

        for (uint256 i = 0; i < handlerAmount; i++) {
            totalRevenueGenerated += handlers[i].revenueGenerated();
        }

        assertEq((rewardPoolBalance + feeBatchBalance + treasuryBalance + harvesterBalance), totalRevenueGenerated);
    }
}
