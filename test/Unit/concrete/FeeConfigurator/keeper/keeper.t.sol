// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { FeeConfigurator_Unit_Concrete_Test } from "../FeeConfigurator.t.sol";

contract Keeper_Unit_Concrete_Test is FeeConfigurator_Unit_Concrete_Test {
    function test_RevertWhen_CallerNotManager() external {
        //Make Alice the caller in this test
        vm.stopPrank();
        vm.startPrank(users.alice);

        vm.expectRevert("!manager");
        feeConfig.setKeeper(users.alice);
    }

    //At the start of each test, the caller is set to the Keeper (Manager)
    modifier whenCallerManager() {
        _;
    }

    function test_SetKeeper_SameKeeper() external whenCallerManager() {
        vm.expectEmit({ emitter: address(feeConfig) });
        emit SetKeeper({ keeper: users.keeper });

        //Set the keeper
        feeConfig.setKeeper(users.keeper);
        
        //Assert Keepers is has remained the same
        address actualKeeper = feeConfig.keeper();
        address expectedKeeper =  users.keeper;
        assertEq(actualKeeper, expectedKeeper, "keeper");
    }

    function test_SetKeeper_ZeroAddress() external whenCallerManager() {
        vm.expectEmit({ emitter: address(feeConfig) });
        emit SetKeeper({ keeper: address(0) });

        //Set the keeper
        feeConfig.setKeeper(address(0));
        
        //Assert Keepers is has remained the same
        address actualKeeper = feeConfig.keeper();
        address expectedKeeper = address(0);
        assertEq(actualKeeper, expectedKeeper, "keeper");
    }

    modifier whenNotZeroAddress() {
        _;
    }

    function test_SetKeeper_NewKeeper() external whenCallerManager whenNotZeroAddress {
        vm.expectEmit({ emitter: address(feeConfig) });
        emit SetKeeper({ keeper: users.alice });

        //Set the keeper
        feeConfig.setKeeper(users.alice);
        
        //Assert Keepers is has remained the same
        address actualKeeper = feeConfig.keeper();
        address expectedKeeper = users.alice;
        assertEq(actualKeeper, expectedKeeper, "keeper");
    }
}