// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import { stdError } from "forge-std/StdError.sol";
import { XERC20TestBase } from "./XERC20Base.t.sol";

contract XERC20LockboxTest is XERC20TestBase {

    address private constant dstUser = 0xdea65d6083A8eFCD9C149FDADEB0Eb7711AeD30c;

    function setUp() public override {
        XERC20TestBase.setUp();

        vm.startPrank(USER);
        goa.approve(address(lockbox), goa.balanceOf(USER));
    }

    function test_Deposit() public {
        lockbox.deposit(goa.balanceOf(USER));

        assertEq(goa.balanceOf(USER), 0);
        assertEq(goa.balanceOf(address(lockbox)), USER_INITIAL_BALANCE);
        assertEq(erc20xGoa.balanceOf(USER), USER_INITIAL_BALANCE);
    }

    function test_Withdraw() public {
        lockbox.deposit(goa.balanceOf(USER));
        erc20xGoa.approve(address(lockbox), erc20xGoa.balanceOf(USER));
        lockbox.withdraw(erc20xGoa.balanceOf(USER));

        assertEq(goa.balanceOf(USER), USER_INITIAL_BALANCE);
        assertEq(goa.balanceOf(address(lockbox)), 0);
        assertEq(erc20xGoa.balanceOf(USER), 0);
    }

    function test_DepositTo() public {
        lockbox.depositTo(dstUser, goa.balanceOf(USER));

        assertEq(goa.balanceOf(USER), 0);
        assertEq(goa.balanceOf(address(lockbox)), USER_INITIAL_BALANCE);
        assertEq(erc20xGoa.balanceOf(dstUser), USER_INITIAL_BALANCE);
    }

    function test_WithdrawTo() public {
        lockbox.deposit(goa.balanceOf(USER));
        erc20xGoa.approve(address(lockbox), erc20xGoa.balanceOf(USER));
        lockbox.withdrawTo(dstUser, erc20xGoa.balanceOf(USER));

        assertEq(goa.balanceOf(dstUser), USER_INITIAL_BALANCE);
        assertEq(goa.balanceOf(address(lockbox)), 0);
        assertEq(erc20xGoa.balanceOf(USER), 0);
    }

    function test_RevertWhen_UserWithNoGoaTriesToDeposit() public {
        goa.transfer(address(0xdead), goa.balanceOf(USER));
        vm.expectRevert();
        lockbox.deposit(USER_INITIAL_BALANCE);
    }

    function test_RevertWhen_UserWithNoXGoaTriesToWithdraw() public {
        erc20xGoa.approve(address(lockbox), USER_INITIAL_BALANCE);
        vm.expectRevert();
        lockbox.withdraw(USER_INITIAL_BALANCE);
    }
}