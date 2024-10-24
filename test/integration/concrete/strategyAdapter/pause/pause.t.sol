// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.8.20 <0.9.0;

import { StrategyAdapter_Integration_Shared_Test } from "../../../shared/StrategyAdapter.t.sol";
import { IStrategyAdapterAdminable } from "interfaces/infra/multistrategy/IStrategyAdapterAdminable.sol";
import { IPausable } from "../../../../shared/TestInterfaces.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";
import { Errors } from "src/infra/libraries/Errors.sol";

contract Pause_Integration_Concrete_Test is StrategyAdapter_Integration_Shared_Test {
    function test_RevertWhen_CallerNotGuardian() external {
        swapCaller(users.bob);

        // Expect a revert
        vm.expectRevert(abi.encodeWithSelector(Errors.CallerNotGuardian.selector, users.bob));
        strategy.pause();
    }

    modifier whenCallerGuardian() {
        IStrategyAdapterAdminable(address(strategy)).enableGuardian(users.guardian);
        swapCaller(users.guardian);
        _;
    }

    function test_RevertWhen_ContractPaused()
        external
        whenCallerGuardian
    {   
        // Pause the strategy
        strategy.pause();

        // Expect a revert
        vm.expectRevert(abi.encodeWithSelector(Pausable.EnforcedPause.selector));
        strategy.pause();
    }

    modifier whenContractNotPaused() {
        _;
    }

    function test_Pause()
        external
        whenCallerGuardian
        whenContractNotPaused
    {
        // Expect the relevant event to be emitted
        vm.expectEmit({emitter: address(strategy)});
        emit Paused(users.guardian);
        
        strategy.pause();

        // Assert contract is paused
        bool actualStrategyPaused = IPausable(address(strategy)).paused();
        bool expectedStrategyPaused = true;
        assertEq(actualStrategyPaused, expectedStrategyPaused, "pause");
    }
}