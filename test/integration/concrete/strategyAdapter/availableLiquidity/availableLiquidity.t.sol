// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.8.20 <0.9.0;

import { StrategyAdapter_Integration_Shared_Test } from "../../../shared/StrategyAdapter.t.sol";

contract AvailableLiquidity_Integration_Concrete_Test is StrategyAdapter_Integration_Shared_Test {
    function test_AvailableLiquidity() public {
        uint256 amount = 1_000 * 10 ** decimals;
        requestCredit(strategy, amount);

        uint256 actualAvailableLiquidity = strategy.availableLiquidity();
        assertEq(actualAvailableLiquidity, amount);
    }
}