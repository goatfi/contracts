// SPDX-License-Identifier: MIT

pragma solidity^0.8.20;

import { RevenueShareTestBase } from "../../unit/RevShare/RevenueShareBase.t.sol";
import { RewardPoolHandler } from "./RewardPoolHandler.sol";
import { RewardPoolActorManager } from "./RewardPoolActorManager.sol";
import { TimestampStore } from "test-utils/TimestampStore.sol";

contract RewardPoolInvariant is RevenueShareTestBase {

    RewardPoolHandler[] private handlers;
    RewardPoolActorManager private manager;
    TimestampStore private timestampStore;

    uint256 handlerAmount = 5;

    function setUp() public override{
        RevenueShareTestBase.setUp();
        timestampStore = new TimestampStore();

        //Handlers[0] will be treated as the owner.
        handlers.push(new RewardPoolHandler(rewardPool, timestampStore));
        _addRewardsBalanceToNotifier(address(handlers[0]));

        rewardPool.setWhitelist(address(handlers[0]), true);
        rewardPool.transferOwnership(address(handlers[0]));

        //Start at i = 1 due to the owner being at index 0
        for (uint256 i = 1; i < handlerAmount; i++) {
            handlers.push(new RewardPoolHandler(rewardPool, timestampStore));
        }

        manager = new RewardPoolActorManager(handlers, rewardPool, timestampStore, goa, weth, TREASURY);
        _approveGOABuys();
        _approveGOASells();
        
        targetContract(address(manager));
    }

    function _approveGOABuys() public {
        vm.startPrank(TREASURY);
        goa.approve(address(manager), type(uint256).max);
    }

    function _approveGOASells() public {
        for (uint256 i = 0; i < handlerAmount; i++) {
            vm.startPrank(address(handlers[i]));
            goa.approve(address(manager), type(uint256).max);
        }
    }

    function _addRewardsBalanceToNotifier(address _notifier) private{
        deal(_notifier, 1000 ether);
        vm.startPrank(_notifier);
        weth.deposit{value: 1000 ether}();
        vm.stopPrank();
    }

    function invariant_totalStaked() public {
        uint256 totalStaked;
        for (uint256 i = 0; i < handlerAmount; i++) {
            totalStaked += manager.stakedAmount(i);
        }

        assertEq(totalStaked, goa.balanceOf(address(rewardPool)));
        assertEq(totalStaked, rewardPool.totalSupply());
    }

    function invariant_rewardsCollected() public {
        uint256 rewardsClaimed;
        for (uint256 i = 0; i < handlerAmount; i++) {
            rewardsClaimed += manager.rewardsClaimed(i);
        }

        uint256 rewardsDistributed = manager.rewardsDistributed();
        uint256 rewardsToBeCollected = weth.balanceOf(address(rewardPool));

        assertEq(rewardsClaimed, rewardsDistributed - rewardsToBeCollected);
    }
}
