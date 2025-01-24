// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.20 <0.9.0;

import { IERC4626, MultistrategyHarness_Integration_Shared_Test } from "../../../shared/MultistrategyHarness.t.sol";
import { IStrategyAdapter } from "interfaces/infra/multistrategy/IStrategyAdapter.sol";

contract FreeFunds_Integration_Concrete_Test is MultistrategyHarness_Integration_Shared_Test {
    function test_FreeFunds_ZeroTotalAssets() external view {
        // Assert that free funds is zero when total Assets is zero
        uint256 actualFreeFunds = multistrategyHarness.freeFunds();
        uint256 expectedFreeFunds = 0;
        assertEq(actualFreeFunds, expectedFreeFunds, "freeFunds");
    }

    modifier whenTotalAssetsNotZero() {
        triggerUserDeposit(users.bob, 1000 ether);
        _;
    }

    function test_FreeFunds_ZeroLockedProfit() 
        external
        whenTotalAssetsNotZero
    {
        uint256 totalAssets = IERC4626(address(multistrategyHarness)).totalAssets();

        // Assert that free funds is totalAssets when locked profit is 0
        uint256 actualFreeFunds = multistrategyHarness.freeFunds();
        uint256 expectedFreeFunds = totalAssets;
        assertEq(actualFreeFunds, expectedFreeFunds, "freeFunds");
    }

    modifier whenLockedProfitNotZero() {
        address strategy = deployMockStrategyAdapter(address(multistrategyHarness), IERC4626(address(multistrategyHarness)).asset());
        multistrategyHarness.addStrategy(strategy, 10000, 0, 100_000 ether);
        IStrategyAdapter(strategy).requestCredit();
        triggerStrategyGain(strategy, 1 ether);
        IStrategyAdapter(strategy).sendReport(0);
        _;
    }

    function test_FreeFunds()
        external
        whenTotalAssetsNotZero
        whenLockedProfitNotZero 
    {
        uint256 totalAssets = IERC4626(address(multistrategyHarness)).totalAssets();
        uint256 lockedProfit = multistrategyHarness.calculateLockedProfit();

        // Assert that free funds is totalAssets minus locked profit
        uint256 actualFreeFunds = multistrategyHarness.freeFunds();
        uint256 expectedFreeFunds = totalAssets - lockedProfit;
        assertEq(actualFreeFunds, expectedFreeFunds, "freeFunds");
    }
}