// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import { BoostTestBase } from "./BoostBase.t.sol";
import { MockERC20 } from "solmate/test/utils/mocks/MockERC20.sol";

contract BoostAdminTest is BoostTestBase {

    function setUp() public override {
        super.setUp();
    }

    function test_transferOwnership() public {
        boost.transferOwnership(OWNER);

        assertEq(boost.owner(), OWNER);
    }

    function test_setTreasury() public {
        address newTreasury = address(0x01);
        boost.setTreasury(newTreasury);

        assertEq(boost.treasury(), newTreasury);
    }

    function test_setTreasuryFee() public {
        uint256 newFee = 100;
        boost.setTreasuryFee(newFee);

        assertEq(boost.treasuryFee(), newFee);
    }

    //TODO: Test for treasury fee above threshold

    function test_setRewardDuration() public {
        uint256 newRewardDuration = 14 days;
        boost.setRewardDuration(newRewardDuration);

        assertEq(boost.duration(), newRewardDuration);
    }

    function test_openPreStake() public {
        boost.openPreStake();

        assertTrue(boost.isPreStake());
    }

    function test_closePreStake() public {
        boost.closePreStake();

        assertFalse(boost.isPreStake());
    }

    function test_setNotifier() public {
        address newNotifier = makeAddr("alice");
        boost.setNotifier(newNotifier, true);

        assertTrue(boost.notifiers(newNotifier));
    }

    function test_inCaseTokensGetStuck() public {
        MockERC20 token = new MockERC20("Mock", "M", 18);
        uint256 amount = 100 ether;
        token.mint(address(this), amount);
        token.transfer(address(boost), amount);

        assertEq(token.balanceOf(address(boost)), amount);
        assertEq(token.balanceOf(address(this)), 0);

        boost.inCaseTokensGetStuck(address(token));

        assertEq(token.balanceOf(address(boost)), 0);
        assertEq(token.balanceOf(address(this)), amount);
    }

    function test_inCaseTokensGetStuck_To() public {
        MockERC20 token = new MockERC20("Mock", "M", 18);
        address account = makeAddr("tom");
        uint256 amount = 100 ether;
        token.mint(address(this), amount);
        token.transfer(address(boost), amount);

        assertEq(token.balanceOf(address(boost)), amount);
        assertEq(token.balanceOf(account), 0);

        boost.inCaseTokensGetStuck(address(token), account, amount);

        assertEq(token.balanceOf(address(boost)), 0);
        assertEq(token.balanceOf(account), amount);
    }
}