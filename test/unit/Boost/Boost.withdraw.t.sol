// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import { BoostTestBase } from "./BoostBase.t.sol";

contract BoostWithdrawTest is BoostTestBase {

    address private user = makeAddr("bob");
    uint256 private amount = 100 ether;
    
    function setUp() public override {
        super.setUp();
    }

    function test_Boost_PartialWithdraw() public {
        airdropStakedTokens(user, amount);
        uint256 amountToWithdraw = amount / 2;

        vm.startPrank(user);

        stakedToken.approve(address(boost), amount);
        boost.stake(amount);
        boost.withdraw(amountToWithdraw);

        vm.stopPrank();

        assertEq(stakedToken.balanceOf(user), amountToWithdraw);
        assertEq(stakedToken.balanceOf(address(boost)), amount - amountToWithdraw);
        assertEq(boost.balanceOf(user), amount - amountToWithdraw);
        assertEq(boost.totalSupply(), amount - amountToWithdraw);
    }

    function test_Boost_FullWithdraw() public {
        airdropStakedTokens(user, amount);

        vm.startPrank(user);

        stakedToken.approve(address(boost), amount);
        boost.stake(amount);
        boost.withdraw(boost.balanceOf(user));

        vm.stopPrank();

        assertEq(stakedToken.balanceOf(user), amount);
        assertEq(stakedToken.balanceOf(address(boost)), 0);
        assertEq(boost.balanceOf(user), 0);
        assertEq(boost.totalSupply(), 0);
    }

    function test_Boost_Exit() public {
        airdropStakedTokens(user, amount);

        vm.startPrank(user);

        stakedToken.approve(address(boost), amount);
        boost.stake(amount);
        boost.exit();

        vm.stopPrank();

        assertEq(stakedToken.balanceOf(user), amount);
        assertEq(stakedToken.balanceOf(address(boost)), 0);
        assertEq(boost.balanceOf(user), 0);
        assertEq(boost.totalSupply(), 0);
    }
}