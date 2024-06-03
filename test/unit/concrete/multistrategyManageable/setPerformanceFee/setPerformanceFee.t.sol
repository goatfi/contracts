// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.20 <0.9.0;

import { Multistrategy_Unit_Shared_Test } from "../../../shared/Multistrategy.t.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Errors } from "src/infra/libraries/Errors.sol";

contract SetPerformanceFee_Unit_Concrete_Test is Multistrategy_Unit_Shared_Test {
    function test_RevertWhen_CallerNotOwner() external {
        // Change caller to bob
        swapCaller(users.bob);
        // 6% performance fee
        uint256 performanceFee = 600;
        
        // Expect a revert
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, users.bob));
        multistrategy.setPerformanceFee(performanceFee);
    }

    modifier whenCallerIsOwner() {
        _;
    }

    function test_RevertWhen_PerformanceFeeAboveMaximum() external whenCallerIsOwner {
        // 100% performance fee.
        uint256 performanceFee = 10_000;

        // Expect a revert
        vm.expectRevert(abi.encodeWithSelector(Errors.ExcessiveFee.selector, performanceFee));
        multistrategy.setPerformanceFee(performanceFee);
    }

    modifier whenBelowMaximumPerformanceFee() {
        _;
    }

    function test_SetPerformanceFee_SamePerformanceFee()
        external
        whenCallerIsOwner
        whenBelowMaximumPerformanceFee
    {
        // 5% performance fee.
        uint256 performanceFee = 500;
        
        // Expect the relevant event to be emitted.
        vm.expectEmit({ emitter: address(multistrategy) });
        emit PerformanceFeeSet(performanceFee);

        multistrategy.setPerformanceFee(performanceFee);

        // Assert performance fee has been set
        uint256 actualPerformanceFee = multistrategy.performanceFee();
        uint256 expectedPerformanceFEe = performanceFee;
        assertEq(actualPerformanceFee, expectedPerformanceFEe, "performance fee");
    }

    function test_PerformanceFee_ZeroPerformanceFee()
        external
        whenCallerIsOwner
        whenBelowMaximumPerformanceFee
    {
        // 0% performance fee.
        uint256 performanceFee = 0;
        
        // Expect the relevant event to be emitted.
        vm.expectEmit({ emitter: address(multistrategy) });
        emit PerformanceFeeSet(performanceFee);

        multistrategy.setPerformanceFee(performanceFee);

        // Assert performance fee has been set
        uint256 actualPerformanceFee = multistrategy.performanceFee();
        uint256 expectedPerformanceFEe = performanceFee;
        assertEq(actualPerformanceFee, expectedPerformanceFEe, "performance fee");
    }

    modifier whenNotZeroPerformanceFee() {
        _;
    }

    function test_SetPerformanceFee_NewPerformanceFee()
        external
        whenCallerIsOwner
        whenBelowMaximumPerformanceFee
        whenNotZeroPerformanceFee
    {
        // 8% performance fee.
        uint256 performanceFee = 800;
        
        // Expect the relevant event to be emitted.
        vm.expectEmit({ emitter: address(multistrategy) });
        emit PerformanceFeeSet(performanceFee);

        multistrategy.setPerformanceFee(performanceFee);

        // Assert performance fee has been set
        uint256 actualPerformanceFee = multistrategy.performanceFee();
        uint256 expectedPerformanceFEe = performanceFee;
        assertEq(actualPerformanceFee, expectedPerformanceFEe, "performance fee");
    }
}