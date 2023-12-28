// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import { GoatFarmTestBase } from "./GoatFarmBase.t.sol";

contract GoatFarmDepositTest is GoatFarmTestBase {

    address user_2 = 0xa023Ca7B3A460c9492782A41794D5fdD60e94Aab;

    function setUp() public override {
        GoatFarmTestBase.setUp();
    }

    function test_Deposit() public {
        _userDepositWETH(USER, 10 ether);
        assertEq(farm.balanceOf(USER), 10 ether);
    }

    function test_RevertWhen_DepositZero() public {
        vm.startPrank(USER);
        vm.expectRevert("Cannot stake 0");
        farm.stake(0);
        vm.stopPrank();
    }

    function test_TotalSupply() public {
        _userDepositWETH(USER, 10 ether);
        _userDepositWETH(user_2, 10 ether);

        assertEq(farm.totalSupply(), 20 ether);
    }
}
