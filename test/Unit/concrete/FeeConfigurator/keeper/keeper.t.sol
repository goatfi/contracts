// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { FeeConfigurator_Unit_Concrete_Test } from "../FeeConfigurator.t.sol";

contract Keeper_Unit_Concrete_Test is FeeConfigurator_Unit_Concrete_Test {
    function setUp() public virtual override {
        super.setUp();

        vm.startPrank({ msgSender: users.owner });
    }

    function test_Keeper() public {
        address keeper = feeConfig.keeper();
        assertEq(keeper, users.keeper, "!keeper");
    }

    function test_Keeper_After_SetKeeper() public {
        feeConfig.setKeeper(users.alice);
        address newKeeper = feeConfig.keeper();
        assertEq(newKeeper, users.alice, "!keeper");
    }
}