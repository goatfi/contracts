// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.20 <0.9.0;

import { IERC4626, Multistrategy_Integration_Shared_Test } from "../../../shared/Multistrategy.t.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import { StrategyAdapterMock } from "../../../../mocks/StrategyAdapterMock.sol";

contract TotalAssets_Integration_Concrete_Test is Multistrategy_Integration_Shared_Test {
    StrategyAdapterMock strategy;
    uint8 decimals;

    function setUp() public virtual override {
        Multistrategy_Integration_Shared_Test.setUp();
        decimals = IERC20Metadata(IERC4626(address(multistrategy)).asset()).decimals();
    }

    function test_TotalAssets_NoDeposits() external view {
        // Assert that totalAssets are as expected
        uint256 actualTotalAssets = IERC4626(address(multistrategy)).totalAssets();
        uint256 expectedTotalAssets = 0;
        assertEq(actualTotalAssets, expectedTotalAssets, "totalAssets");
    }

    modifier whenThereAreDeposits() {
        triggerUserDeposit(users.bob, 1_000 * 10 ** decimals);
        _;
    }

    function test_TotalAssets_NoActiveStrategy() 
        external 
        whenThereAreDeposits
    {
        // Assert that totalAssets are as expected
        uint256 actualTotalAssets = IERC4626(address(multistrategy)).totalAssets();
        uint256 expectedTotalAssets = 1_000 * 10 ** decimals;
        assertEq(actualTotalAssets, expectedTotalAssets, "totalAssets");
    }

    modifier whenActiveStrategy() {
        // Add the strategy to the multistrategy
        strategy = deployMockStrategyAdapter(address(multistrategy), IERC4626(address(multistrategy)).asset());
        multistrategy.addStrategy(address(strategy), 5_000, 100 * 10 ** decimals, 100_000 * 10 ** decimals);
        _;
    }

    function test_TotalAssets_NoCreditRequested()
        external
        whenThereAreDeposits
        whenActiveStrategy
    {
        // Assert that totalAssets are as expected
        uint256 actualTotalAssets = IERC4626(address(multistrategy)).totalAssets();
        uint256 expectedTotalAssets = 1_000 * 10 ** decimals;
        assertEq(actualTotalAssets, expectedTotalAssets, "totalAssets");
    }

    modifier whenCreditRequested() {
        // Request the credit from the strategy
        strategy.requestCredit();
        _;
    }

    function test_TotalAssets_CreditRequested()
        external
        whenThereAreDeposits
        whenActiveStrategy
        whenCreditRequested
    {
        // Assert that totalAssets are as expected
        uint256 actualTotalAssets = IERC4626(address(multistrategy)).totalAssets();
        uint256 expectedTotalAssets = 1_000 * 10 ** decimals;
        assertEq(actualTotalAssets, expectedTotalAssets, "totalAssets");
    }
}