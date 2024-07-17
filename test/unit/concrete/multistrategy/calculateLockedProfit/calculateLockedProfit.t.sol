// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.20 <0.9.0;

import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { MultistrategyHarness_Unit_Shared_Test } from "../../../shared/MultistrategyHarness.t.sol";
import { IStrategyAdapter } from "interfaces/infra/multistrategy/IStrategyAdapter.sol";

contract CalculateLockedProfit_Unit_Concrete_Test is MultistrategyHarness_Unit_Shared_Test {
    using Math for uint256;
    
    address strategy;
    uint256 strategyProfit = 100 ether;
    uint256 constant PROFIT_UNLOCK_TIME = 12 hours;

    function test_CalculateLockedProfit_NoPriorLockedProfit() 
        external
    {   
        uint256 actualLockedProfit = multistrategyHarness.calculateLockedProfit();
        uint256 expectedLockedProfit = 0;
        assertEq(actualLockedProfit, expectedLockedProfit, "calculateLockedProfit");
    }

    modifier whenThereIsPriorProfit() {
        // Strategy deployed and added
        strategy = deployMockStrategyAdapter(address(multistrategyHarness), multistrategyHarness.baseAsset());
        multistrategyHarness.addStrategy(strategy, 5_000, 100 ether, 10_000 ether);

        //User deposits
        triggerUserDeposit(users.bob, 1000 ether);

        // Strategy makes gain
        triggerStrategyGain(strategy, strategyProfit);
        
        // Strategy reports
        IStrategyAdapter(strategy).sendReport(0);
        _;
    }

    function test_CalculateLockedProfit_TimeSinceLastReportAboveUnlockTime()
        external
        whenThereIsPriorProfit
    {
        vm.warp(block.timestamp + PROFIT_UNLOCK_TIME + 1);

        // Assert that locked profit is 0
        uint256 actualLockedProfit = multistrategyHarness.calculateLockedProfit();
        uint256 expectedLockedProfit = 0;
        assertEq(actualLockedProfit, expectedLockedProfit, "calculateLockedProfit");
    }

    modifier whenTimeSinceLastReportLowerThanUnlockTime() {
        _;
    }

    function test_CalculateLockedProfit() 
        external
        whenThereIsPriorProfit
        whenTimeSinceLastReportLowerThanUnlockTime
    {
        // Assert that locked profit is 95% of the gain at t = 0, as it has fees deduced
        uint256 actualLockedProfit = multistrategyHarness.calculateLockedProfit();
        uint256 expectedLockedProfit = strategyProfit.mulDiv(95, 100);
        assertEq(actualLockedProfit, expectedLockedProfit, "calculateLockedProfit");

        // Advance half of the unlock time
        vm.warp(block.timestamp + PROFIT_UNLOCK_TIME / 2);

        // Assert that locked profit is 47.5% of the gain at t = 6h
        // Due to rounding precision, it will give a margin of 0,001%
        actualLockedProfit = multistrategyHarness.calculateLockedProfit();
        expectedLockedProfit = strategyProfit.mulDiv(475, 1000);
        assertApproxEqRel(actualLockedProfit, expectedLockedProfit, 0.00001 ether, "calculateLockedProfit");
    }
}