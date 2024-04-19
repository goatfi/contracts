// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import { BoostTestBase } from "./BoostBase.t.sol";

contract BoostDepositTest is BoostTestBase {

    address private user = makeAddr("bob");
    uint256 private amount = 100 ether;
    
    function setUp() public override {
        super.setUp();
    }

    function test_Boost_Deposit() public {
        airdropStakedTokens(user, amount);

        vm.startPrank(user);

        stakedToken.approve(address(boost), amount);
        boost.stake(amount);

        vm.stopPrank();

        assertEq(stakedToken.balanceOf(user), 0);
        assertEq(stakedToken.balanceOf(address(boost)), amount);
        assertEq(boost.balanceOf(user), amount);
        assertEq(boost.totalSupply(), amount);
    }
}