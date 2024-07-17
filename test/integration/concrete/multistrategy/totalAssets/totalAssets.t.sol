// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.20 <0.9.0;

import { Multistrategy_Integration_Shared_Test } from "../../../shared/Multistrategy.t.sol";
import { IStrategyAdapter } from "interfaces/infra/multistrategy/IStrategyAdapter.sol";

contract TotalAssets_Integration_Concrete_Test is Multistrategy_Integration_Shared_Test {
    address strategy;

    function test_TotalAssets_NoDeposits() external {
        // Assert that totalAssets are as expected
        uint256 actualTotalAssets = multistrategy.totalAssets();
        uint256 expectedTotalAssets = 0;
        assertEq(actualTotalAssets, expectedTotalAssets, "totalAssets");
    }

    modifier whenThereAreDeposits() {
        triggerUserDeposit(users.bob, 1_000 ether);
        _;
    }

    function test_TotalAssets_NoActiveStrategy() 
        external 
        whenThereAreDeposits
    {
        // Assert that totalAssets are as expected
        uint256 actualTotalAssets = multistrategy.totalAssets();
        uint256 expectedTotalAssets = 1_000 ether;
        assertEq(actualTotalAssets, expectedTotalAssets, "totalAssets");
    }

    modifier whenActiveStrategy() {
        // Add the strategy to the multistrategy
        strategy = deployMockStrategyAdapter(address(multistrategy), multistrategy.baseAsset());
        multistrategy.addStrategy(strategy, 5_000, 100 ether, 100_000 ether);
        _;
    }

    function test_TotalAssets_NoCreditRequested()
        external
        whenThereAreDeposits
        whenActiveStrategy
    {
        // Assert that totalAssets are as expected
        uint256 actualTotalAssets = multistrategy.totalAssets();
        uint256 expectedTotalAssets = 1_000 ether;
        assertEq(actualTotalAssets, expectedTotalAssets, "totalAssets");
    }

    modifier whenCreditRequested() {
        // Request the credit from the strategy
        IStrategyAdapter(strategy).requestCredit();
        _;
    }

    function test_TotalAssets_CreditRequested()
        external
        whenThereAreDeposits
        whenActiveStrategy
        whenCreditRequested
    {
        // Assert that totalAssets are as expected
        uint256 actualTotalAssets = multistrategy.totalAssets();
        uint256 expectedTotalAssets = 1_000 ether;
        assertEq(actualTotalAssets, expectedTotalAssets, "totalAssets");
    }
}