// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.20 <0.9.0;

import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { IERC4626, MultistrategyHarness_Unit_Shared_Test } from "../../../shared/MultistrategyHarness.t.sol";
import { IStrategyAdapter } from "interfaces/infra/multistrategy/IStrategyAdapter.sol";

contract CalculateLockedProfit_Unit_Concrete_Test is MultistrategyHarness_Unit_Shared_Test {
    using Math for uint256;

    address strategy;
    uint256 strategyProfit = 100 ether;

    function test_CalculateLockedProfit_NoPriorLockedProfit() 
        external view
    {   
        uint256 actualLockedProfit = multistrategyHarness.calculateLockedProfit();
        uint256 expectedLockedProfit = 0;
        assertEq(actualLockedProfit, expectedLockedProfit, "calculateLockedProfit");
    }

    modifier whenThereIsPriorProfit() {
        // Strategy deployed and added
        strategy = deployMockStrategyAdapter(address(multistrategyHarness), IERC4626(address(multistrategyHarness)).asset());
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
        vm.warp(block.timestamp + multistrategyHarness.profitUnlockTime() + 1);

        // Assert that locked profit is 0
        uint256 actualLockedProfit = multistrategyHarness.calculateLockedProfit();
        uint256 expectedLockedProfit = 0;
        assertEq(actualLockedProfit, expectedLockedProfit, "calculateLockedProfit");
    }

    modifier whenTimeSinceLastReportLowerThanUnlockTime() {
        _;
    }

    /// @dev While there is some profit that is being unlocked, add more profit.
    function test_CalculateLockedProfit_OverwriteProfit() 
        external
        whenThereIsPriorProfit
        whenTimeSinceLastReportLowerThanUnlockTime
    {
        // Advance half of the unlock time
        vm.warp(block.timestamp + multistrategyHarness.profitUnlockTime() / 2);

        // Add some profit again
        triggerStrategyGain(strategy, strategyProfit);
        IStrategyAdapter(strategy).sendReport(0);

        uint256 actualLockedProfit = multistrategyHarness.calculateLockedProfit();
        uint256 expectedLockedProfit = strategyProfit.mulDiv(95, 100) + strategyProfit.mulDiv(475, 1000);
        assertApproxEqRel(actualLockedProfit, expectedLockedProfit, 0.00001 ether, "calculateLockedProfit");

        // Advance the unlock time
        vm.warp(block.timestamp + multistrategyHarness.profitUnlockTime() + 1);

        // Assert that there is no locked profit
        actualLockedProfit = multistrategyHarness.calculateLockedProfit();
        expectedLockedProfit = 0;
        assertEq(actualLockedProfit, expectedLockedProfit, "calculateLockedProfit");

        // Assert all profit has been distributed to the multistrategy
        uint256 actualMultistrategyAssets = IERC4626(address(multistrategyHarness)).totalAssets();
        uint256 expectedMultistrategyAssets = 1000 ether + (strategyProfit.mulDiv(95, 100) * 2);
        assertEq(actualMultistrategyAssets, expectedMultistrategyAssets, "calculateLockedProfit, multistrategy assets");
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
        vm.warp(block.timestamp + multistrategyHarness.profitUnlockTime() / 2);

        // Assert that locked profit is 47.5% of the gain at t = 6h
        // Due to rounding precision, it will give a margin of 0,001%
        actualLockedProfit = multistrategyHarness.calculateLockedProfit();
        expectedLockedProfit = strategyProfit.mulDiv(475, 1000);
        assertApproxEqRel(actualLockedProfit, expectedLockedProfit, 0.00001 ether, "calculateLockedProfit");
    }
}