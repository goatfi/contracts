// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.20 <0.9.0;

import { IERC4626, MultistrategyHarness_Integration_Shared_Test } from "../../../shared/MultistrategyHarness.t.sol";

contract FreeFunds_Integration_Concrete_Test is MultistrategyHarness_Integration_Shared_Test {
    function test_FreeFunds_ZeroTotalAssets() external {
        // Assert that free funds is zero when total Assets is zero
        uint256 actualFreeFunds = multistrategyHarness.freeFunds();
        uint256 expectedFreeFunds = 0;
        assertEq(actualFreeFunds, expectedFreeFunds, "freeFunds");
    }

    modifier whenTotalAssetsNotZero() {
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