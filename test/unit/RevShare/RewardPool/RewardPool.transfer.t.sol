// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import { RevenueShareTestBase } from "../RevenueShareBase.t.sol";

contract RewardPoolTransferTest is RevenueShareTestBase {

    address private constant USER = 0x000069694Af23C2A26CBe50fAeE034B2e034FABc;
    uint256 private constant DEPOSIT_AMOUNT = 1000 ether;
    uint256 private constant REVENUE_AMOUNT = 1 ether;

    function setUp() public override {
        RevenueShareTestBase.setUp();
        deal(address(goa), USER, DEPOSIT_AMOUNT);

        weth.deposit{value: REVENUE_AMOUNT}();
        weth.transfer(address(feeBatch), weth.balanceOf(address(this)));
        feeBatch.harvest();
    }

    modifier UserStakeAction() {
        vm.startPrank(USER);
        goa.approve(address(rewardPool), DEPOSIT_AMOUNT);
        rewardPool.stake(DEPOSIT_AMOUNT);
        vm.stopPrank();
        _;
    }

    function test_transfer() public UserStakeAction {
        vm.warp(block.timestamp + 1 days);
        uint256 earned = rewardPool.earned(USER, address(weth));

        vm.startPrank(USER);
        rewardPool.transfer(address(this), rewardPool.balanceOf(USER));
        vm.stopPrank();

        assertEq(rewardPool.balanceOf(address(this)), DEPOSIT_AMOUNT);
        assertEq(rewardPool.earned(USER, address(weth)), earned);
        assertEq(rewardPool.earned(address(this), address(weth)), 0);

        vm.warp(block.timestamp + 1 days);
        
        assertEq(rewardPool.earned(address(this), address(weth)), earned);
    }

    function test_transferFrom() public UserStakeAction {
        vm.warp(block.timestamp + 1 days);
        uint256 earned = rewardPool.earned(USER, address(weth));

        vm.prank(USER);
        rewardPool.approve(address(this), DEPOSIT_AMOUNT);
        rewardPool.transferFrom(USER, address(this), rewardPool.balanceOf(USER));

        assertEq(rewardPool.balanceOf(address(this)), DEPOSIT_AMOUNT);
        assertEq(rewardPool.earned(USER, address(weth)), earned);
        assertEq(rewardPool.earned(address(this), address(weth)), 0);

        vm.warp(block.timestamp + 1 days);
        
        assertGt(rewardPool.earned(address(this), address(weth)), 0);
    }
}