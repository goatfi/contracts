// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.20 <0.9.0;

import { Multistrategy_Integration_Shared_Test } from "../../../shared/Multistrategy.t.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Errors } from "src/infra/libraries/Errors.sol";

/// @dev By default, the caller of these functions is the owner of the Multistrategy unless specified
/// by calling swapCaller.
contract SetManager_Integration_Concrete_Test is Multistrategy_Integration_Shared_Test {
    function test_RevertWhen_CallerNotOwner() external {
        // Change caller to bob
        swapCaller(users.bob);
        
        // Expect a revert
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, users.bob));
        multistrategy.setManager(users.bob);
    }

    modifier whenCallerOwner() {
        _;
    }

    function test_SetManager_SameManager() external whenCallerOwner {
        // Expect the relevant event to be emitted.
        vm.expectEmit();
        emit ManagerSet({ manager: users.keeper });

        // Set the manager
        multistrategy.setManager(users.keeper);

        // Assert the manager has been set
        address actualManager = multistrategy.manager();
        address expectedManager = users.keeper;
        assertEq(actualManager, expectedManager, "manager");
    }

    function test_SetManager_ZeroAddress() external whenCallerOwner {
        // Expect the relevant event to be emitted.
        vm.expectEmit();
        emit ManagerSet({ manager: address(0) });

        // Set the manager
        multistrategy.setManager(address(0));

        // Assert the manager has been set
        address actualManager = multistrategy.manager();
        address expectedManager = address(0);
        assertEq(actualManager, expectedManager, "manager");
    }

    modifier whenNotZeroAddress() {
        _;
    }

    function test_SetManager_NewManager() external whenCallerOwner whenNotZeroAddress {
        // Expect the relevant event to be emitted.
        vm.expectEmit();
        emit ManagerSet({ manager: users.bob });

        // Set the manager
        multistrategy.setManager(users.bob);

        // Assert the manager has been set
        address actualManager = multistrategy.manager();
        address expectedManager = users.bob;
        assertEq(actualManager, expectedManager, "manager");
    }
}