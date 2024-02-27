// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import { GoatFarmTestBase } from "./GoatFarmBase.t.sol";

contract GoatFarmRewardsTest is GoatFarmTestBase {

    uint256 private constant FARM_REWARD = 1000 ether;

    function setUp() public override {
        GoatFarmTestBase.setUp();
        _userDepositWETH(USER, 10 ether);
    }

    function test_SetNotifier() public {
        farm.setNotifier(TREASURY, true);
        assert(farm.notifiers(TREASURY));
    }

    function test_NotifyRewards() public {
        _notifyRewards(FARM_REWARD);
        assertEq(rewardToken.balanceOf(address(farm)), FARM_REWARD);
        assertEq(farm.lastUpdateTime(), block.timestamp);
        assertEq(farm.periodFinish(), block.timestamp + DURATION);
        assertEq(farm.rewardRate(), FARM_REWARD / DURATION);
    }

    function test_NotifyRewardsWhileInActivePeriod() public {
        _notifyRewards(FARM_REWARD);
        vm.warp(block.timestamp + DURATION / 2);
        _notifyRewards(FARM_REWARD);

        assertEq(farm.rewardRate(), 1.5 ether);
    }

    function test_RewardDuration() public {
        farm.setRewardDuration(5000);
        assertEq(farm.duration(), 5000);
    }

    function test_TransferRewardAndThenNotify() public {
        vm.startPrank(TREASURY);
        rewardToken.transfer(address(farm), 1000);
        farm.notifyAlreadySent();
        vm.stopPrank();

        assertEq(farm.rewardRate(), 1);
    }

    function test_RevertWhen_ChangeDurationWhileInActivePeriod() public {
        _notifyRewards(FARM_REWARD);
        vm.warp(block.timestamp + DURATION / 2);

        vm.expectRevert();
        farm.setRewardDuration(5000);
    }

    function test_RevertWhen_NotifiedAmountIsZero() public {
        vm.startPrank(TREASURY);

        vm.expectRevert("no rewards");
        farm.notifyAmount(0 ether);

        vm.stopPrank();
    }

    function test_Earned() public {
        _notifyRewards(FARM_REWARD);
        vm.warp(block.timestamp + DURATION);
        assertEq(farm.earned(USER), FARM_REWARD);
    }

    function test_GetReward() public {
        _notifyRewards(FARM_REWARD);
        vm.warp(block.timestamp + DURATION);

        uint256 previousRewardTokenBalance = rewardToken.balanceOf(USER);

        vm.prank(USER);
        farm.getReward();

        assertEq(previousRewardTokenBalance, 0);
        assertEq(rewardToken.balanceOf(USER), FARM_REWARD);
    }

    function test_Exit() public {
        _notifyRewards(FARM_REWARD);
        vm.warp(block.timestamp + DURATION);

        vm.prank(USER);
        farm.exit();

        assertEq(stakedToken.balanceOf(USER), 10 ether);
        assertEq(rewardToken.balanceOf(USER), FARM_REWARD);
    }
}
