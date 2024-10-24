// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import { RevenueShareTestBase } from "../RevenueShareBase.t.sol";

contract RewardPoolSettersTest is RevenueShareTestBase {

    function setUp() public override {
        RevenueShareTestBase.setUp();
    }

    function test_Ownership() public {
        vm.startPrank(BLACKHAT);
        vm.expectRevert();
        rewardPool.transferOwnership(BLACKHAT);
        vm.stopPrank();

        rewardPool.transferOwnership(TREASURY);
        assertEq(rewardPool.owner(), TREASURY);
    }

    function test_SetWhitelist() public {
        rewardPool.setWhitelist(TREASURY, true);

        vm.startPrank(BLACKHAT);
        vm.expectRevert();
        rewardPool.setWhitelist(BLACKHAT, true);
        vm.stopPrank();

        assert(rewardPool.whitelisted(TREASURY));
    }
}