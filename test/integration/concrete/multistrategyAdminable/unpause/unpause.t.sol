// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.20 <0.9.0;

import { Multistrategy_Integration_Shared_Test } from "../../../shared/Multistrategy.t.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";
import { Errors } from "src/infra/libraries/Errors.sol";

interface IPausable {
    function paused() external view returns (bool);
}

contract Unpause_Integration_Concrete_Test is Multistrategy_Integration_Shared_Test {
    function test_RevertWhen_CallerNotGuardian() external {
        // Change caller to bob
        swapCaller(users.bob);
        
        // Expect a revert
        vm.expectRevert(abi.encodeWithSelector(Errors.CallerNotGuardian.selector, users.bob));
        multistrategy.pause();
    }

    modifier whenCallerIsGuardian() {
        swapCaller(users.guardian);
        _;
    }

    function test_RevertWhen_ContractIsUnpaused() external whenCallerIsGuardian {
        // Expect a revert.
        vm.expectRevert(abi.encodeWithSelector(Pausable.ExpectedPause.selector));
        multistrategy.unpause();
    }

    modifier whenContractIsPaused() {
        multistrategy.pause();
        _;
    }

    function test_Unpause_PausedContract() external whenCallerIsGuardian whenContractIsPaused {
        // Expect the relevant event to be emitted.
        vm.expectEmit({ emitter: address(multistrategy) });
        emit Unpaused({ account: users.guardian });

        // Pause the contract.
        multistrategy.unpause();

        // Assert that the contract has been paused.
        bool isPaused = IPausable(address(multistrategy)).paused();
        bool expectedToBePaused = false;
        assertEq(isPaused, expectedToBePaused, "unpause");
    }
}