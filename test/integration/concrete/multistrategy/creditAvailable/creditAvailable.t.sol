// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.20 <0.9.0;

import { Multistrategy_Integration_Shared_Test } from "../../../shared/Multistrategy.t.sol";
import { IStrategyAdapter } from "interfaces/infra/multistrategy/IStrategyAdapter.sol";

contract CreditAvailable_Integration_Concrete_Test is Multistrategy_Integration_Shared_Test {
    address strategy;
    uint256 minDebtDelta = 100 ether;
    uint256 maxDebtDelta = 10_000 ether;

    function test_CreditAvailable_ZeroAddress() external {
        strategy = address(0);

        uint256 actualCreditAvailable = multistrategy.creditAvailable(strategy);
        uint256 expectedCreditAvailable = 0;
        assertEq(actualCreditAvailable, expectedCreditAvailable, "creditAvailable");
    }

    modifier whenNotZeroAddress() {
        strategy = deployMockStrategyAdapter(address(multistrategy), multistrategy.depositToken());
        _;
    }

    function test_CreditAvailable_NoDeposits()
        external
        whenNotZeroAddress
    {
        uint256 actualCreditAvailable = multistrategy.creditAvailable(strategy);
        uint256 expectedCreditAvailable = 0;
        assertEq(actualCreditAvailable, expectedCreditAvailable, "creditAvailable");
    }

    modifier whenThereAreDeposits() {
        triggerUserDeposit(users.bob, 1_000 ether);
        _;
    }

    function test_CreditAvailable_NotActiveStrategy()
        external
        whenNotZeroAddress
        whenThereAreDeposits
    {
        uint256 actualCreditAvailable = multistrategy.creditAvailable(strategy);
        uint256 expectedCreditAvailable = 0;
        assertEq(actualCreditAvailable, expectedCreditAvailable, "creditAvailable");
    }

    modifier whenActiveStrategy() {
        multistrategy.addStrategy(strategy, 5_000, minDebtDelta, maxDebtDelta);
        _;
    }

    function test_CreditAvailable_AboveDebtLimit()
        external
        whenNotZeroAddress
        whenThereAreDeposits
        whenActiveStrategy
    {
        // Strategy requests a credit. So it will have the same debt as the limit
        IStrategyAdapter(strategy).requestCredit();
        // We need to reduce the debt ratio of the strategy to lower the limit.
        multistrategy.setStrategyDebtRatio(strategy, 2_500);

        // As the strategy has more debt than its limit, there is no credit available
        uint256 actualCreditAvailable = multistrategy.creditAvailable(strategy);
        uint256 expectedCreditAvailable = 0;
        assertEq(actualCreditAvailable, expectedCreditAvailable, "creditAvailable");
    }    
       
    function test_CreditAvailable_DebtEqualAsDebtLimit()
        external
        whenNotZeroAddress
        whenThereAreDeposits
        whenActiveStrategy
    {
        // Strategy requests a credit. So it will have the same debt as the limit
        IStrategyAdapter(strategy).requestCredit();

        // As the strategy has the same debt as its limit, there is no credit available
        uint256 actualCreditAvailable = multistrategy.creditAvailable(strategy);
        uint256 expectedCreditAvailable = 0;
        assertEq(actualCreditAvailable, expectedCreditAvailable, "creditAvailable");
    }

    /// @dev at this point, the strategy did not ask for a credit, so the debt is
    /// below the debt limit. 
    modifier whenDebtBelowDebtLimit() {
        _;
    }

    function test_CreditAvailable_CreditBelowMinDebtDelta()
        external
        whenNotZeroAddress
        whenThereAreDeposits
        whenActiveStrategy
        whenDebtBelowDebtLimit
    {
        // Strategy requests a credit. So it will have the same debt as the limit
        IStrategyAdapter(strategy).requestCredit();

        // We increase the debt limit 0.1%, with 1K deposited, this means the strategy can
        // take a credit of 1 extra token.
        multistrategy.setStrategyDebtRatio(strategy, 5_010);

        // As 1 token of credit is below the minDebtDelta (100 tokens), assert credit available is 0
        uint256 actualCreditAvailable = multistrategy.creditAvailable(strategy);
        uint256 expectedCreditAvailable = 0;
        assertEq(actualCreditAvailable, expectedCreditAvailable, "creditAvailable");
    }

    modifier whenCreditAboveMinDebtDelta() {
        _;
    }

    function test_CreditAvailable_CreditAboveMaxDebtDelta()
        external
        whenNotZeroAddress
        whenThereAreDeposits
        whenActiveStrategy
        whenDebtBelowDebtLimit
        whenCreditAboveMinDebtDelta
    {   
        // Max debt delta is 10K, so we need a big deposit in order to ask for a big credit
        triggerUserDeposit(users.alice, 25_000 ether);

        // Assert creditAvailable is maxDebtDelta
        uint256 actualCreditAvailable = multistrategy.creditAvailable(strategy);
        uint256 expectedCreditAvailable = maxDebtDelta;
        assertEq(actualCreditAvailable, expectedCreditAvailable, "creditAvailable");
    }

    modifier whenCreditBelowMaxDebtDelta() {
        _;
    }

    function test_CreditAvailable()
        external
        whenNotZeroAddress
        whenThereAreDeposits
        whenActiveStrategy
        whenDebtBelowDebtLimit
        whenCreditAboveMinDebtDelta
        whenCreditBelowMaxDebtDelta
    {
        uint256 actualCreditAvailable = multistrategy.creditAvailable(strategy);
        uint256 expectedCreditAvailable = 500 ether;
        assertEq(actualCreditAvailable, expectedCreditAvailable, "creditAvailable");
    }
}