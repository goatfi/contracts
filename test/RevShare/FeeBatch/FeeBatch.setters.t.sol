// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import { RevenueShareTestBase } from "../RevenueShareBase.t.sol";

contract FeeBatchSettersTest is RevenueShareTestBase {

    error Duration(uint256 duration);

    function setUp() public override {
        RevenueShareTestBase.setUp();
    }

    function test_Ownership() public {
        vm.startPrank(BLACKHAT);
        vm.expectRevert();
        feeBatch.transferOwnership(BLACKHAT);
        vm.stopPrank();

        feeBatch.transferOwnership(TREASURY);
        assertEq(feeBatch.owner(), TREASURY);
    }

    function test_SetRewardPool() public {
        feeBatch.setRewardPool(address(0));

        vm.startPrank(BLACKHAT);
        vm.expectRevert();
        feeBatch.setRewardPool(BLACKHAT);
        vm.stopPrank();

        assertEq(feeBatch.rewardPool(), address(0));
    }

    function test_SetTreasury() public {
        feeBatch.setTreasury(address(0));

        vm.startPrank(BLACKHAT);
        vm.expectRevert();
        feeBatch.setTreasury(BLACKHAT);
        vm.stopPrank();

        assertEq(feeBatch.treasury(), address(0));
    }

    function test_SetTreasuryFee() public {
        feeBatch.setTreasuryFee(1000);

        vm.startPrank(BLACKHAT);
        vm.expectRevert();
        feeBatch.setTreasuryFee(1000);
        vm.stopPrank();

        assertEq(feeBatch.treasuryFee(), 499);
    }

    function test_SetSendHarvesterGas() public {
        feeBatch.setSendHarvesterGas(true);

        vm.startPrank(BLACKHAT);
        vm.expectRevert();
        feeBatch.setSendHarvesterGas(true);
        vm.stopPrank();

        assertEq(feeBatch.sendHarvesterGas(), true);
    }

    function test_SetHarvesterConfig() public {
        uint256 harvesterMax = 0.01 ether;
        feeBatch.setHarvesterConfig(HARVESTER, harvesterMax);

        vm.startPrank(BLACKHAT);
        vm.expectRevert();
        feeBatch.setHarvesterConfig(BLACKHAT, 1 ether);
        vm.stopPrank();

        assertEq(feeBatch.harvester(), HARVESTER);
        assertEq(feeBatch.harvesterMax(), harvesterMax);
    }

    function test_SetDuration() public {
        vm.expectRevert(abi.encodeWithSelector(Duration.selector, 0));
        feeBatch.setDuration(0);
        vm.expectRevert(abi.encodeWithSelector(Duration.selector, 366 days));
        feeBatch.setDuration(366 days);

        feeBatch.setDuration(7 days);

        vm.startPrank(BLACKHAT);
        vm.expectRevert();
        feeBatch.setDuration(1 days);
        vm.stopPrank();

        assertEq(feeBatch.duration(), 7 days);
    }
}