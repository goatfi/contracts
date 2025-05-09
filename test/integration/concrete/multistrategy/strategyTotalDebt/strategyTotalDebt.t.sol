// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.20 <0.9.0;

import { IERC4626, Multistrategy_Integration_Shared_Test } from "../../../shared/Multistrategy.t.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import { StrategyAdapterMock } from "../../../../mocks/StrategyAdapterMock.sol";

contract StrategyTotalDebt_Integration_Concrete_Test is Multistrategy_Integration_Shared_Test {
    StrategyAdapterMock strategy;
    uint8 decimals;

    function setUp() public virtual override {
        Multistrategy_Integration_Shared_Test.setUp();
        decimals = IERC20Metadata(IERC4626(address(multistrategy)).asset()).decimals();
    }

    function test_StrategyTotalDebt_ZeroAddress() external view {
        // Assert that zero address has 0 debt
        uint256 actualStrategyTotalDebt = multistrategy.strategyTotalDebt(address(0));
        uint256 expectedStrategyTotalDebt = 0;
        assertEq(actualStrategyTotalDebt, expectedStrategyTotalDebt, "strategyTotalDebt");
    }

    modifier whenNotZeroAddress() {
        strategy = deployMockStrategyAdapter(address(multistrategy), IERC4626(address(multistrategy)).asset());
        _;
    }

    function test_StrategyTotalDebt_NoActiveStrategy() external whenNotZeroAddress {
        // Assert that a not active strategy has 0 debt
        uint256 actualStrategyTotalDebt = multistrategy.strategyTotalDebt(address(strategy));
        uint256 expectedStrategyTotalDebt = 0;
        assertEq(actualStrategyTotalDebt, expectedStrategyTotalDebt, "strategyTotalDebt");
    }

    modifier whenActiveStrategy() {
        // Add the strategy to the multistrategy
        multistrategy.addStrategy(address(strategy), 5_000, 100 * 10 ** decimals, 100_000 * 10 ** decimals);
        _;
    }

    function test_StrategyTotalDebt_NoCreditRequested() 
        external 
        whenNotZeroAddress
        whenActiveStrategy
    {
        // Assert debt is 0 as the strategy hasn't requested any credit
        uint256 actualStrategyTotalDebt = multistrategy.strategyTotalDebt(address(strategy));
        uint256 expectedStrategyTotalDebt = 0;
        assertEq(actualStrategyTotalDebt, expectedStrategyTotalDebt, "strategyTotalDebt");
    }

    modifier whenCreditRequested() {
        // We need some funds into the multistrategy, else no credit can be requested
        triggerUserDeposit(users.bob, 1_000 * 10 ** decimals);

        // Request the credit from the strategy
        strategy.requestCredit();
        _;
    }

    function test_StrategyTotalDebt_CreditRequested() 
        external
        whenNotZeroAddress
        whenActiveStrategy
        whenCreditRequested
    {
        // Debt should be half the user deposit, as strategy's debtRatio is 50%
        uint256 creditRequested = 500 * 10 ** decimals;

        // Assert the strategy total debt is the same as the credit requested
        uint256 actualStrategyTotalDebt = multistrategy.strategyTotalDebt(address(strategy));
        uint256 expectedStrategyTotalDebt = creditRequested;
        assertEq(actualStrategyTotalDebt, expectedStrategyTotalDebt, "strategyTotalDebt");
    }
}