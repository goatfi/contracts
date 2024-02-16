// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import { RevenueShareTestBase } from "../RevenueShareBase.t.sol";
import { SigUtils } from "../../utils/SigUtils.sol";

contract RewardPoolPermitTest is RevenueShareTestBase {
    SigUtils internal sigUtils;

    uint256 internal ownerPrivateKey;

    address internal owner;
    address internal spender;

    function setUp() public override {
        super.setUp();
        sigUtils = new SigUtils(goa.DOMAIN_SEPARATOR());

        ownerPrivateKey = 0xA11CE;

        owner = vm.addr(ownerPrivateKey);
        spender = address(rewardPool);

        deal(address(goa), owner, 1000 ether);
    }

    function test_Permit() public {
        SigUtils.Permit memory permit = SigUtils.Permit({
            owner: owner,
            spender: spender,
            value: 1e18,
            nonce: 0,
            deadline: 1 days
        });

        bytes32 digest = sigUtils.getTypedDataHash(permit);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);

        goa.permit(
            permit.owner,
            permit.spender,
            permit.value,
            permit.deadline,
            v,
            r,
            s
        );

        assertEq(goa.allowance(owner, spender), 1e18);
        assertEq(goa.nonces(owner), 1);
    }

    function test_StakeWithPermit() public {
        uint256 stakeAmount = goa.balanceOf(owner); 

        SigUtils.Permit memory permit = SigUtils.Permit({
            owner: owner,
            spender: spender,
            value: stakeAmount,
            nonce: 0,
            deadline: 1 days
        });

        bytes32 digest = sigUtils.getTypedDataHash(permit);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);

        rewardPool.stakeWithPermit(
            permit.owner,
            stakeAmount,
            permit.deadline,
            v, 
            r, 
            s
        );

        assertEq(goa.balanceOf(spender), stakeAmount);
        assertEq(goa.balanceOf(owner), 0);
        assertEq(rewardPool.balanceOf(owner), stakeAmount);
    }

    /// @dev Test that staking with permit still goes through even if
    /// and attacker is frontrunning the permit.
    function test_PermitGriefing() public {
        uint256 stakeAmount = goa.balanceOf(owner); 

        SigUtils.Permit memory permit = SigUtils.Permit({
            owner: owner,
            spender: spender,
            value: stakeAmount,
            nonce: 0,
            deadline: 1 days
        });

        bytes32 digest = sigUtils.getTypedDataHash(permit);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);

        ///Here the user sends the tx to the mempool

        /// Attacker frontruns the permit.
        vm.prank(makeAddr("Attacker"));
        goa.permit(
            permit.owner,
            permit.spender,
            permit.value,
            permit.deadline,
            v,
            r,
            s
        );

        assertEq(goa.allowance(owner, spender), stakeAmount);

        /// Victim's tx goes through
        rewardPool.stakeWithPermit(
            permit.owner,
            stakeAmount,
            permit.deadline,
            v, 
            r, 
            s
        );

        assertEq(goa.balanceOf(spender), stakeAmount);
        assertEq(goa.balanceOf(owner), 0);
        assertEq(rewardPool.balanceOf(owner), stakeAmount);
    }
}