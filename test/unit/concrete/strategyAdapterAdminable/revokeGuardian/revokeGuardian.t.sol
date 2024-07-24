// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { StrategyAdapter_Unit_Shared_Test } from "../../../shared/StrategyAdapter.t.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Errors } from "src/infra/libraries/Errors.sol";

contract RevokeGuardian_Unit_Concrete_Test is StrategyAdapter_Unit_Shared_Test {
    function test_RevertWhen_CallerNotOwner() external {
        // Change caller to bob
        swapCaller(users.bob);
        
        // Expect a revert
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, users.bob));
        multistrategy.revokeGuardian(users.bob);
    }

    modifier whenCallerOwner() {
        _;
    }

    /// @dev Aready revoked also means that hasn't been enabled
    function test_RevokeGuardian_AlreadyRevokedGuardian() external whenCallerOwner {
        // Expect the relevant event to be emitted.
        vm.expectEmit({ emitter: address(multistrategy) });
        emit GuardianRevoked({ guardian: users.alice });

        // Enable the guardian
        multistrategy.revokeGuardian(users.alice);

        // Assert the guardian has been revoked
        bool isEnabled = multistrategy.guardians(users.alice);
        bool expectedToBeEnabled = false;
        assertEq(isEnabled, expectedToBeEnabled, "revoke guardian");
    }

    function test_RevokeGuardian_ZeroAddress() external whenCallerOwner {
        // Expect the relevant event to be emitted.
        vm.expectEmit({ emitter: address(multistrategy) });
        emit GuardianRevoked({ guardian: address(0) });

        // Enable the guardian
        multistrategy.revokeGuardian(address(0));

        // Assert the address(0) has been revoked
        bool isEnabled = multistrategy.guardians(address(0));
        bool expectedToBeEnabled = false;
        assertEq(isEnabled, expectedToBeEnabled, "revoke guardian");
    }

    modifier whenNotZeroAddress() {
        _;
    }

    function test_RevokeGuardian_EnabledGuardian() 
        external 
        whenCallerOwner 
        whenNotZeroAddress
    {
        // Expect the relevant event to be emitted.
        vm.expectEmit({ emitter: address(multistrategy) });
        emit GuardianRevoked({ guardian: users.guardian });

        // Enable the guardian
        multistrategy.revokeGuardian(users.guardian);

        // Assert the address(0) has been enabled
        bool isEnabled = multistrategy.guardians(users.guardian);
        bool expectedToBeEnabled = false;
        assertEq(isEnabled, expectedToBeEnabled, "revoke guardian");
    }
}