// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { StrategyAdapter_Unit_Shared_Test } from "../../../shared/StrategyAdapter.t.sol";
import { IStrategyAdapterAdminable } from "interfaces/infra/multistrategy/IStrategyAdapterAdminable.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Errors } from "src/infra/libraries/Errors.sol";

contract RevokeGuardian_Unit_Concrete_Test is StrategyAdapter_Unit_Shared_Test {
    function test_RevertWhen_CallerNotOwner() external {
        // Change caller to bob
        swapCaller(users.bob);
        
        // Expect a revert
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, users.bob));
        IStrategyAdapterAdminable(address(strategy)).revokeGuardian(users.bob);
    }

    modifier whenCallerOwner() {
        _;
    }

    function test_RevokeGuardian_AlreadyRevokedGuardian() external whenCallerOwner {
        IStrategyAdapterAdminable(address(strategy)).revokeGuardian(users.alice);

        // Expect the relevant event to be emitted.
        vm.expectEmit({ emitter: address(strategy) });
        emit GuardianRevoked({ guardian: users.alice });

        // Revoke the guardian
        IStrategyAdapterAdminable(address(strategy)).revokeGuardian(users.alice);

        // Assert the guardian has been revoked
        bool isEnabled = IStrategyAdapterAdminable(address(strategy)).guardians(users.alice);
        bool expectedToBeEnabled = false;
        assertEq(isEnabled, expectedToBeEnabled, "revoke guardian");
    }

    function test_RevokeGuardian_ZeroAddress() external whenCallerOwner {
        // Expect the relevant event to be emitted.
        vm.expectEmit({ emitter: address(strategy) });
        emit GuardianRevoked({ guardian: address(0) });

        // Revoke the guardian
        IStrategyAdapterAdminable(address(strategy)).revokeGuardian(address(0));

        // Assert the address(0) has been revoked
        bool isEnabled = IStrategyAdapterAdminable(address(strategy)).guardians(address(0));
        bool expectedToBeEnabled = false;
        assertEq(isEnabled, expectedToBeEnabled, "revoke guardian");
    }

    modifier whenNotZeroAddress() {
        _;
    }

    function test_RevokeGuardian() 
        external 
        whenCallerOwner 
        whenNotZeroAddress
    {
        IStrategyAdapterAdminable(address(strategy)).enableGuardian(users.guardian);
        
        // Expect the relevant event to be emitted.
        vm.expectEmit({ emitter: address(strategy) });
        emit GuardianRevoked({ guardian: users.guardian });

        // Revoke the guardian
        IStrategyAdapterAdminable(address(strategy)).revokeGuardian(users.guardian);

        // Assert the address(0) has been revoked
        bool isEnabled = IStrategyAdapterAdminable(address(strategy)).guardians(users.guardian);
        bool expectedToBeEnabled = false;
        assertEq(isEnabled, expectedToBeEnabled, "revoke guardian");
    }
}