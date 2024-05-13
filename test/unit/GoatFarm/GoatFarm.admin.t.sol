// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import { GoatFarmTestBase } from "./GoatFarmBase.t.sol";

contract GoatFarmAdminTest is GoatFarmTestBase {

    function setUp() public override {
        GoatFarmTestBase.setUp();
    }

    function test_TransferOwnership() public {
        farm.transferOwnership(TREASURY);
        assertEq(farm.owner(), TREASURY);
    }

    function test_RevertWhen_UnAuthTransferOwnership() public {
        vm.startPrank(USER);
        vm.expectRevert();
        farm.transferOwnership(USER);
        vm.expectRevert();
        farm.transferOwnership(address(0));
        vm.stopPrank();
    }

    function test_RescueTokens() public {
        _userDepositWETH(USER, 10 ether);
        _notifyRewards(1000 ether);

        farm.inCaseTokensGetStuck(address(rewardToken));
        assertEq(rewardToken.balanceOf(address(farm)), 0);
        assertEq(rewardToken.balanceOf(address(this)), 1000 ether);
    }

    function test_RevertWhen_RescueTokenIsStakedToken() public {
        _userDepositWETH(USER, 10 ether);
        _notifyRewards(1000 ether);

        vm.expectRevert("!staked");
        farm.inCaseTokensGetStuck(address(stakedToken));
    }
}