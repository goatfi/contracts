// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.20 <0.9.0;

import { Multistrategy_Integration_Shared_Test } from "../../../shared/Multistrategy.t.sol";
import { IStrategyAdapter } from "interfaces/infra/multistrategy/IStrategyAdapter.sol";

contract DebtExcess_Integration_Concrete_Test is Multistrategy_Integration_Shared_Test {
    address strategy;

    function test_DebtExcess_ZeroAddress() external {
        uint256 actualDebtExcess = multistrategy.debtExcess(strategy);
        uint256 expectedDebtExcess = 0;
        assertEq(actualDebtExcess, expectedDebtExcess, "debtExcess");
    }

    modifier whenNotZeroAddress() {
        strategy = deployMockStrategyAdapter(address(multistrategy), multistrategy.depositToken());
        _;
    }

    function test_DebtExcess_NoDeposits()
        external
        whenNotZeroAddress
    {
        uint256 actualDebtExcess = multistrategy.debtExcess(strategy);
        uint256 expectedDebtExcess = 0;
        assertEq(actualDebtExcess, expectedDebtExcess, "debtExcess");
    }

    modifier whenThereAreDeposits() {
        triggerUserDeposit(users.bob, 1_000 ether);
        _;
    }

    function test_DebtExcess_NotActiveStrategy()
        external
        whenNotZeroAddress
        whenThereAreDeposits
    {
        uint256 actualDebtExcess = multistrategy.debtExcess(strategy);
        uint256 expectedDebtExcess = 0;
        assertEq(actualDebtExcess, expectedDebtExcess, "debtExcess");
    }

    modifier whenActiveStrategy() {
        multistrategy.addStrategy(strategy, 5_000, 100 ether, 100_000 ether);
        _;
    }

    function test_DebtExcess_ZeroDebtRatio() 
        external
        whenNotZeroAddress
        whenThereAreDeposits
        whenActiveStrategy
    {
        // Strategy requests a credit. So it will have debt
        IStrategyAdapter(strategy).requestCredit();

        // Set the strategy debt ratio to 0, so all debt is excess debt
        multistrategy.setStrategyDebtRatio(strategy, 0);

        uint256 actualDebtExcess = multistrategy.debtExcess(strategy);
        uint256 expectedDebtExcess = multistrategy.strategyTotalDebt(strategy);
        assertEq(actualDebtExcess, expectedDebtExcess, "debtExcess");
    }

    modifier whenNotZeroDebtRatio() {
        _;
    }

    function test_DebtExcess_DebtBelowDebtLimit()
        external
        whenNotZeroAddress
        whenThereAreDeposits
        whenActiveStrategy
        whenNotZeroDebtRatio
    {
        // Strategy requests a credit. So it will have debt
        IStrategyAdapter(strategy).requestCredit();

        // Set the strategy debt ratio to 60%, so strategy's debt is below the debt limit
        multistrategy.setStrategyDebtRatio(strategy, 6_000);

        uint256 actualDebtExcess = multistrategy.debtExcess(strategy);
        uint256 expectedDebtExcess = 0;
        assertEq(actualDebtExcess, expectedDebtExcess, "debtExcess");
    }

    modifier whenDebtAboveDebtLimit() {
        _;
    }

    function test_DebtExcess_DebtAboveDebtLimit()
        external
        whenNotZeroAddress
        whenThereAreDeposits
        whenActiveStrategy
        whenNotZeroDebtRatio
        whenDebtAboveDebtLimit
    {
        // Strategy requests a credit. So it will have debt
        IStrategyAdapter(strategy).requestCredit();

        // Set the strategy debt ratio to 40%, so strategy's debt is above the debt limit
        multistrategy.setStrategyDebtRatio(strategy, 4_000);

        uint256 actualDebtExcess = multistrategy.debtExcess(strategy);
        uint256 expectedDebtExcess = 100 ether;
        assertEq(actualDebtExcess, expectedDebtExcess, "debtExcess");
    }
}