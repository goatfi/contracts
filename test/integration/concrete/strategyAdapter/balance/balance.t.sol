// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.8.20 <0.9.0;

import { StrategyAdapter_Integration_Shared_Test } from "../../../shared/StrategyAdapter.t.sol";

contract Balance_Integration_Concrete_Test is StrategyAdapter_Integration_Shared_Test {
    function test_Balance() public {
        uint256 amount = 1 ether;
        deal(address(asset), address(strategy), amount);

        uint256 actualBalance = strategy.balance();
        assertEq(actualBalance, amount);
    }
}