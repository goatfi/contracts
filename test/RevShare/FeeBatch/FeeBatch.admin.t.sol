// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import { RevenueShareTestBase } from "../RevenueShareBase.t.sol";

contract FeeBatchHarvestTest is RevenueShareTestBase {

    error WithdrawingRewardToken();

    uint256 amountToRescue = 1000 ether;

    function setUp() public override {
        RevenueShareTestBase.setUp();
        vm.prank(TREASURY);
        goa.transfer(address(feeBatch), amountToRescue);
    }

    function test_OwnerCanRescueToken() public {
        feeBatch.rescueTokens(address(goa), address(this));

        assertEq(goa.balanceOf(address(this)), amountToRescue);
        assertEq(goa.balanceOf(address(feeBatch)), 0);
    }   

    function test_ReveertWhen_BlackhatRescuesToken() public {
        vm.startPrank(BLACKHAT);
        vm.expectRevert();
        feeBatch.rescueTokens(address(goa), address(this));
        vm.stopPrank();
    }

    function test_RevertWhen_OwnerRescueRevenue() public {
        uint256 revenueAmount = 1 ether;

        weth.deposit{value: revenueAmount}();
        weth.transfer(address(feeBatch), weth.balanceOf(address(this)));
        assertEq(weth.balanceOf(address(feeBatch)), revenueAmount);

        vm.expectRevert(WithdrawingRewardToken.selector);
        feeBatch.rescueTokens(address(weth), address(this));

        assertEq(weth.balanceOf(address(feeBatch)), revenueAmount);
    }
}