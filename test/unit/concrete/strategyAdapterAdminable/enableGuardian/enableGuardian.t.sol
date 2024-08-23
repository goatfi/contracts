// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { StrategyAdapter_Unit_Shared_Test } from "../../../shared/StrategyAdapter.t.sol";
import { IStrategyAdapterAdminable } from "interfaces/infra/multistrategy/IStrategyAdapterAdminable.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Errors } from "src/infra/libraries/Errors.sol";

contract EnableGuardian_Unit_Concrete_Test is StrategyAdapter_Unit_Shared_Test {
    function test_RevertWhen_CallerNotOwner() external {
        // Change caller to bob
        swapCaller(users.bob);
        
        // Expect a revert
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, users.bob));
        IStrategyAdapterAdminable(address(strategy)).enableGuardian(users.bob);
    }

    modifier whenCallerOwner() {
        _;
    }
    
    function test_EnableGuardian_AlreadyEnabledGuardian() external whenCallerOwner {
        IStrategyAdapterAdminable(address(strategy)).enableGuardian(users.alice);

        // Expect the relevant event to be emitted.
        vm.expectEmit({ emitter: address(strategy) });
        emit GuardianEnabled({ guardian: users.alice });

        // Enable the guardian
        IStrategyAdapterAdminable(address(strategy)).enableGuardian(users.alice);

        // Assert the guardian has been revoked
        bool isEnabled = IStrategyAdapterAdminable(address(strategy)).guardians(users.alice);
        bool expectedToBeEnabled = true;
        assertEq(isEnabled, expectedToBeEnabled, "enable guardian");
    }

    function test_EnableGuardian_ZeroAddress() external whenCallerOwner {
        // Expect the relevant event to be emitted.
        vm.expectEmit({ emitter: address(strategy) });
        emit GuardianEnabled({ guardian: address(0) });

        // Enable the guardian
        IStrategyAdapterAdminable(address(strategy)).enableGuardian(address(0));

        // Assert the address(0) has been revoked
        bool isEnabled = IStrategyAdapterAdminable(address(strategy)).guardians(address(0));
        bool expectedToBeEnabled = true;
        assertEq(isEnabled, expectedToBeEnabled, "enable guardian");
    }

    modifier whenNotZeroAddress() {
        _;
    }

    function test_EnabledGuardian() 
        external 
        whenCallerOwner 
        whenNotZeroAddress
    {
        // Expect the relevant event to be emitted.
        vm.expectEmit({ emitter: address(strategy) });
        emit GuardianEnabled({ guardian: users.guardian });

        // Enable the guardian
        IStrategyAdapterAdminable(address(strategy)).enableGuardian(users.guardian);

        // Assert the address(0) has been enabled
        bool isEnabled = IStrategyAdapterAdminable(address(strategy)).guardians(users.guardian);
        bool expectedToBeEnabled = true;
        assertEq(isEnabled, expectedToBeEnabled, "enable guardian");
    }
}