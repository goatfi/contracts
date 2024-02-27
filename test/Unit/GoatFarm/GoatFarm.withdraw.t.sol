// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import { stdError } from "forge-std/StdError.sol";
import { GoatFarmTestBase } from "./GoatFarmBase.t.sol";

contract GoatFarmWithdrawTest is GoatFarmTestBase {

    function setUp() public override {
        GoatFarmTestBase.setUp();
    }

    function test_Withdraw() public {
        _userDepositWETH(USER, 10 ether);
        uint256 balance = farm.balanceOf(USER);
        vm.prank(USER);
        farm.withdraw(balance);

        assertEq(stakedToken.balanceOf(USER), 10 ether);
    }

    function test_RevertWhen_WithdrawZero() public {
        vm.startPrank(USER);
        vm.expectRevert("Cannot withdraw 0");
        farm.withdraw(0);
        vm.stopPrank();
    }

    function test_RevertWhen_WithdawAmountHigherThanBalance() public {
        vm.startPrank(USER);
        vm.expectRevert(stdError.arithmeticError);
        farm.withdraw(10 ether);
        vm.stopPrank();
    }

    function test_ExitWithNoRewards() public {
        _userDepositWETH(USER, 10 ether);
        vm.prank(USER);
        farm.exit();

        assertEq(stakedToken.balanceOf(USER), 10 ether);
    }
}
