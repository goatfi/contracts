// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { Test } from "forge-std/Test.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { CurveLPBase} from "src/abstracts/CurveLPBase.sol";
import { CurveLPBaseMock } from "test/mocks/abstracts/CurveLPBaseMock.sol";
import { Errors } from "src/infra/libraries/Errors.sol";

contract SetWithdrawBufferPPM_Unit_Concrete_Test is Test {
    CurveLPBaseMock adapter;

    address owner = makeAddr('Owner');
    address notOwner = makeAddr('notOwner');

    function setUp() public {
        adapter = new CurveLPBaseMock(makeAddr('CurveLP'), makeAddr('CurveSlippageUtility'));
        adapter.transferOwnership(owner);
    }

    function test_RevertWhen_CallerNotOwner() public {
        uint256 ppm = 500;
        vm.startPrank(notOwner);
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector, 
                notOwner
            )
        );
        adapter.setWithdrawBufferPPM(ppm);
        vm.stopPrank();
    }

    modifier whenCallerIsOwner() {
        vm.stopPrank();
        vm.startPrank(owner);
        _;
    }

    function test_RevertWhen_zeroPPM() whenCallerIsOwner public {
        vm.expectRevert(abi.encodeWithSelector(CurveLPBase.InvalidPPM.selector, 0));
        adapter.setWithdrawBufferPPM(0);
    }

    function test_RevertWhen_PPMTooHigh() whenCallerIsOwner public {
        vm.expectRevert(abi.encodeWithSelector(CurveLPBase.InvalidPPM.selector, 10_001));
        adapter.setWithdrawBufferPPM(10_001);
    }

    function test_SetBufferPPM() whenCallerIsOwner public {
        uint256 ppm = 500;
        uint256 expected = 1_000_000 + ppm;

        adapter.setWithdrawBufferPPM(ppm);
        assertEq(adapter.withdrawBuffer(), expected);
    }
}