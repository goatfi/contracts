// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.20 <0.9.0;

import { Multistrategy_Unit_Shared_Test } from "../../../shared/Multistrategy.t.sol";
import { Errors } from "src/infra/libraries/Errors.sol";

contract SetDepositLimit_Unit_Concrete_Test is Multistrategy_Unit_Shared_Test {
    function test_RevertWhen_CallerNotManager() external {
        // Change caller to bob
        swapCaller(users.bob);
        // Set deposit limit to 50K tokens
        uint256 depositLimit = 50_000 ether;
        
        // Expect a revert
        vm.expectRevert(abi.encodeWithSelector(Errors.CallerNotManager.selector, users.bob));
        multistrategy.setDepositLimit(depositLimit);
    }

    modifier whenCallerIsManager() {
        swapCaller(users.keeper);
        _;
    }

    function test_SetDepositLimit_SameDepositLimit()
        external
        whenCallerIsManager
    {
        // Set deposit limit to 100K tokens
        uint256 depositLimit = 100_000 ether;
        
        // Expect the relevant event to be emitted.
        vm.expectEmit({ emitter: address(multistrategy) });
        emit DepositLimitSet(depositLimit);

        multistrategy.setDepositLimit(depositLimit);

        // Assert deposit limit has been set
        uint256 actualDepositLimit = multistrategy.depositLimit();
        uint256 expectedDepositLImit = depositLimit;
        assertEq(actualDepositLimit, expectedDepositLImit, "deposit limit");
    }

    function test_SetDepositLimit_ZeroDepositLimit()
        external
        whenCallerIsManager
    {
        // Set deposit limit to 0 tokens
        uint256 depositLimit = 0 ether;

        // Expect the relevant event to be emitted.
        vm.expectEmit({ emitter: address(multistrategy) });
        emit DepositLimitSet(depositLimit);

        multistrategy.setDepositLimit(depositLimit);

        // Assert deposit limit has been set
        uint256 actualDepositLimit = multistrategy.depositLimit();
        uint256 expectedDepositLImit = depositLimit;
        assertEq(actualDepositLimit, expectedDepositLImit, "deposit limit");
    }

    modifier whenNotZeroDepositLimit() {
        _;
    }

    function test_SetDepositLimit_NewDepositLimit()
        external
        whenCallerIsManager
        whenNotZeroDepositLimit
    {
        // Set deposit limit to 500K tokens
        uint256 depositLimit = 500_000 ether;

       // Expect the relevant event to be emitted.
        vm.expectEmit({ emitter: address(multistrategy) });
        emit DepositLimitSet(depositLimit);

        multistrategy.setDepositLimit(depositLimit);

        // Assert deposit limit has been set
        uint256 actualDepositLimit = multistrategy.depositLimit();
        uint256 expectedDepositLImit = depositLimit;
        assertEq(actualDepositLimit, expectedDepositLImit, "deposit limit");
    }
}