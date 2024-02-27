// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import { RevenueShareTestBase } from "../RevenueShareBase.t.sol";

contract RewardPoolRewardsTest is RevenueShareTestBase {

    address private constant USER = 0x000069694Af23C2A26CBe50fAeE034B2e034FABc;
    uint256 private constant DEPOSIT_AMOUNT = 1000 ether;
    uint256 private constant REVENUE_AMOUNT = 1 ether;
    uint256 private constant DURATION = 7 days;


    function setUp() public override {
        RevenueShareTestBase.setUp();
        deal(address(goa), USER, DEPOSIT_AMOUNT);

        weth.deposit{value: REVENUE_AMOUNT}();
        weth.transfer(address(feeBatch), weth.balanceOf(address(this)));
    }

    modifier UserStakeAction() {
        vm.startPrank(USER);
        goa.approve(address(rewardPool), DEPOSIT_AMOUNT);
        rewardPool.stake(DEPOSIT_AMOUNT);
        vm.stopPrank();
        _;
    }

    function test_Stake() public UserStakeAction {
        assertEq(rewardPool.balanceOf(USER), DEPOSIT_AMOUNT);
        assertEq(goa.balanceOf(address(rewardPool)), DEPOSIT_AMOUNT);
    }

    function test_Withdraw() public UserStakeAction {
        vm.prank(USER);
        rewardPool.withdraw(DEPOSIT_AMOUNT);

        assertEq(goa.balanceOf(USER), DEPOSIT_AMOUNT);
        assertEq(goa.balanceOf(address(rewardPool)), 0);
        assertEq(rewardPool.balanceOf(USER), 0);
    }

    function test_GetReward() public UserStakeAction {
        feeBatch.harvest();

        vm.warp(block.timestamp + 7 days);

        vm.prank(USER);
        rewardPool.getReward();

        assertApproxEqAbs(weth.balanceOf(USER), REVENUE_AMOUNT, 1e-12 ether);
    }

    function test_Exit() public UserStakeAction {
        feeBatch.harvest();

        vm.warp(block.timestamp + 7 days);

        vm.prank(USER);
        rewardPool.exit();
        
        assertEq(goa.balanceOf(USER), DEPOSIT_AMOUNT);
        assertApproxEqAbs(weth.balanceOf(USER), REVENUE_AMOUNT, 1e-12 ether);
    }

    function test_RewardInfo() public {
        feeBatch.harvest();

        (address reward, 
        uint256 periodFinish, 
        uint256 duration, 
        uint256 lastUpdateTime , 
        uint256 rate) = rewardPool.rewardInfo(0);

        assertEq(reward, address(weth));
        assertEq(periodFinish, block.timestamp + DURATION);
        assertEq(duration, DURATION);
        assertEq(lastUpdateTime, block.timestamp);
        assertEq(rate, 1 ether / DURATION);
    }

    function test_Earned() public UserStakeAction {
        feeBatch.harvest();

        vm.warp(block.timestamp + 7 days);

        (address[] memory rewardTokens, uint256[] memory earnedAmounts) = rewardPool.earned(USER);
        assertEq(rewardTokens[0], address(weth));
        assertApproxEqAbs(earnedAmounts[0], REVENUE_AMOUNT, 1e-12 ether);
    }

    function test_EarnedToken() public UserStakeAction {
        feeBatch.harvest();

        vm.warp(block.timestamp + 7 days);

        uint256 earned = rewardPool.earned(USER, address(weth));
        assertApproxEqAbs(earned, REVENUE_AMOUNT, 1e-12 ether);
    }
}