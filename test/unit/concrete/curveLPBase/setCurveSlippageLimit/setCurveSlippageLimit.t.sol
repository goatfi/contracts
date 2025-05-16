// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { Test } from "forge-std/Test.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { CurveLPBaseMock } from "test/mocks/abstracts/CurveLPBaseMock.sol";
import { Errors } from "src/infra/libraries/Errors.sol";

contract SetCurveSlippageLimit_Unit_Concrete_Test is Test {
    CurveLPBaseMock adapter;

    address owner = makeAddr('Owner');
    address notOwner = makeAddr('notOwner');

    function setUp() public {
        adapter = new CurveLPBaseMock(makeAddr('CurveLP'), makeAddr('CurveSlippageUtility'));
        adapter.transferOwnership(owner);
    }

    function test_RevertWhen_CallerNotOwner() public {
        uint256 newLimit = 50 ether;
        vm.startPrank(notOwner);
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector, 
                notOwner
            )
        );
        adapter.setCurveSlippageLimit(newLimit);
        vm.stopPrank();
    }

    modifier whenCallerIsOwner() {
        vm.stopPrank();
        vm.startPrank(owner);
        _;
    }

    function test_RevertWhen_SlippageAboveLimit() whenCallerIsOwner public {
        uint256 excessiveLimit = 101 ether;

        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.SlippageLimitExceeded.selector, 
                excessiveLimit
            )
        );
        adapter.setCurveSlippageLimit(excessiveLimit);
    }

    function test_SetCurveSlippageLimit() whenCallerIsOwner public {
        uint256 newLimit = 50 ether;

        adapter.setCurveSlippageLimit(newLimit);

        assertEq(adapter.curveSlippageLimit(), newLimit);
    }
}