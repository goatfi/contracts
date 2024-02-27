// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import { RevenueShareTestBase } from "../RevenueShareBase.t.sol";
import { MockToken } from "src/mocks/MockToken.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract RewardPoolAdminTest is RevenueShareTestBase {

    error WithdrawingStakedToken();
    error WithdrawingRewardToken(address reward);
    error RewardNotFound(address reward);

    uint256 amountToRescue = 1000 ether;

    function setUp() public override {
        RevenueShareTestBase.setUp();
    }

    function test_RevertWhen_BlackhatRescuesToken() public {
        vm.startPrank(BLACKHAT);
        vm.expectRevert();
        rewardPool.rescueTokens(address(goa), address(this));
        vm.stopPrank();
    }

    function test_RevertWhen_OwnerRescueRewards() public {
        uint256 revenueAmount = 1 ether;

        weth.deposit{value: revenueAmount}();
        weth.transfer(address(feeBatch), weth.balanceOf(address(this)));
        feeBatch.harvest();
        assertEq(weth.balanceOf(address(rewardPool)), revenueAmount);

        vm.expectRevert(abi.encodeWithSelector(WithdrawingRewardToken.selector, address(weth)));
        rewardPool.rescueTokens(address(weth), address(this));

        assertEq(weth.balanceOf(address(rewardPool)), revenueAmount);
    }

    function test_RevertWhen_OwnerRescueStaked() public {
        vm.expectRevert(WithdrawingStakedToken.selector);
        rewardPool.rescueTokens(address(goa), address(this));
    }

    function test_RescueTokens() public {
        uint256 balanceToRescue = 1000 ether;
        IERC20 t = new MockToken(balanceToRescue, "Mock", "MOCK");
        deal(address(t), address(this), balanceToRescue);
        t.transfer(address(rewardPool), balanceToRescue);

        assertEq(t.balanceOf(address(rewardPool)), balanceToRescue);
        
        rewardPool.rescueTokens(address(t), TREASURY);
        assertEq(t.balanceOf(TREASURY), balanceToRescue);
    }

    function test_RemoveReward() public {
        uint256 revenueAmount = 1 ether;

        weth.deposit{value: revenueAmount}();
        weth.transfer(address(feeBatch), weth.balanceOf(address(this)));
        feeBatch.harvest();

        rewardPool.removeReward(address(weth), TREASURY);
        assertEq(weth.balanceOf(TREASURY), revenueAmount);
        assertEq(weth.balanceOf(address(rewardPool)), 0);
    }

    function test_RevertWhen_RemoveInexistentReward() public {
        vm.expectRevert(abi.encodeWithSelector(RewardNotFound.selector, address(goa)));
        rewardPool.removeReward(address(goa), TREASURY);
    }

    function test_RevertWhen_BlackhatRemovesReward() public {
        uint256 revenueAmount = 1 ether;

        weth.deposit{value: revenueAmount}();
        weth.transfer(address(feeBatch), weth.balanceOf(address(this)));
        feeBatch.harvest();

        vm.startPrank(BLACKHAT);
        vm.expectRevert();
        rewardPool.removeReward(address(weth), TREASURY);
        vm.stopPrank();
    }
}