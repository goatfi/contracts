// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.20 <0.9.0;

import { Multistrategy_Integration_Shared_Test } from "../../../shared/Multistrategy.t.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Errors } from "src/infra/libraries/Errors.sol";

contract EnableGuardian_Integration_Concrete_Test is Multistrategy_Integration_Shared_Test {
    function test_RevertWhen_CallerNotOwner() external {
        // Change caller to bob
        swapCaller(users.bob);
        
        // Expect a revert
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, users.bob));
        multistrategy.enableGuardian(users.bob);
    }

    modifier whenCallerOwner() {
        _;
    }

    function test_EnableGuardian_AlreadyEnabledGuardian() external whenCallerOwner {
        // Expect the relevant event to be emitted.
        vm.expectEmit();
        emit GuardianEnabled({ guardian: users.guardian });

        // Enable the guardian
        multistrategy.enableGuardian(users.guardian);

        // Assert the guardian has been enabled
        bool isEnabled = multistrategy.guardians(users.guardian);
        bool expectedToBeEnabled = true;
        assertEq(isEnabled, expectedToBeEnabled, "enable guardian");
    }

    function test_EnableGuardian_ZeroAddress() external whenCallerOwner {
        // Expect the relevant event to be emitted.
        vm.expectEmit();
        emit GuardianEnabled({ guardian: address(0) });

        // Enable the guardian
        multistrategy.enableGuardian(address(0));

        // Assert the address(0) has been enabled
        bool isEnabled = multistrategy.guardians(address(0));
        bool expectedToBeEnabled = true;
        assertEq(isEnabled, expectedToBeEnabled, "enable guardian");
    }

    modifier whenNotZeroAddress() {
        _;
    }

    function test_EnableGuardian_NotEnabledGuardian() 
        external 
        whenCallerOwner 
        whenNotZeroAddress
    {
        // Expect the relevant event to be emitted.
        vm.expectEmit();
        emit GuardianEnabled({ guardian: users.bob });

        // Enable the guardian
        multistrategy.enableGuardian(users.bob);

        // Assert the address(0) has been enabled
        bool isEnabled = multistrategy.guardians(users.bob);
        bool expectedToBeEnabled = true;
        assertEq(isEnabled, expectedToBeEnabled, "enable guardian");
    }
}