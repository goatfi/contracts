// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import { RevenueShareTestBase } from "../RevenueShareBase.t.sol";

contract FeeBatchSettersTest is RevenueShareTestBase {

    error Duration(uint256 duration);
    error InvalidZeroAddress();
    error InvalidTreasuryFee(uint256 fee);

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
        vm.startPrank(BLACKHAT);
        vm.expectRevert();
        feeBatch.setRewardPool(BLACKHAT);
        vm.stopPrank();

        feeBatch.setRewardPool(address(rewardPool));
        assertEq(feeBatch.rewardPool(), address(rewardPool));
    }

    function test_SetTreasury() public {
        vm.expectRevert(InvalidZeroAddress.selector);
        feeBatch.setTreasury(address(0));

        vm.startPrank(BLACKHAT);
        vm.expectRevert();
        feeBatch.setTreasury(BLACKHAT);
        vm.stopPrank();

        feeBatch.setTreasury(TREASURY);
        assertEq(feeBatch.treasury(), TREASURY);
    }

    function test_SetTreasuryFee() public {
        vm.expectRevert(abi.encodeWithSelector(InvalidTreasuryFee.selector, 1000));
        feeBatch.setTreasuryFee(1000);

        vm.startPrank(BLACKHAT);
        vm.expectRevert();
        feeBatch.setTreasuryFee(1000);
        vm.stopPrank();

        feeBatch.setTreasuryFee(10);
        assertEq(feeBatch.treasuryFee(), 10);
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
        uint256 minHarvesterGas = 0.01 ether;
        feeBatch.setHarvesterConfig(HARVESTER, minHarvesterGas);

        vm.startPrank(BLACKHAT);
        vm.expectRevert();
        feeBatch.setHarvesterConfig(BLACKHAT, 1 ether);
        vm.stopPrank();

        assertEq(feeBatch.harvester(), HARVESTER);
        assertEq(feeBatch.minHarvesterGas(), minHarvesterGas);
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