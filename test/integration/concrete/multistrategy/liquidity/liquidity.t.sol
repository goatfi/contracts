// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.20 <0.9.0;

import { IERC4626, MultistrategyHarness_Integration_Shared_Test } from "../../../shared/MultistrategyHarness.t.sol";
import { IStrategyAdapter } from "interfaces/infra/multistrategy/IStrategyAdapter.sol";

contract Liquidity_Integration_Concrete_Test is MultistrategyHarness_Integration_Shared_Test {
    uint256 depositAmount = 1000 ether;

    function test_Liquidity_NoCredit() external {
        triggerUserDeposit(users.bob, depositAmount);

        uint256 actualLiquidity = multistrategyHarness.liquidity();
        uint256 expectedLiquidity = depositAmount;
        assertEq(actualLiquidity, expectedLiquidity, "liquidity");
    }

    modifier whenActiveCredit() {
        triggerUserDeposit(users.bob, depositAmount);
        address strategy = deployMockStrategyAdapter(address(multistrategyHarness), IERC4626(address(multistrategyHarness)).asset());
        multistrategyHarness.addStrategy(strategy, 6_000, 0, 100_000 ether);
        IStrategyAdapter(strategy).requestCredit();
        _;
    }

    function test_Liquidity_ActiveCredit()
        external
        whenActiveCredit
    {
        uint256 actualLiquidity = multistrategyHarness.liquidity();
        uint256 expectedLiquidity = depositAmount - 600 ether;
        assertEq(actualLiquidity, expectedLiquidity, "liquidity");
    }
}