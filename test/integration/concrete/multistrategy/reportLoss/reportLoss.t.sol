// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.20 <0.9.0;

import { IStrategyAdapter } from "interfaces/infra/multistrategy/IStrategyAdapter.sol";
import { IERC4626, MultistrategyHarness_Integration_Shared_Test } from "../../../shared/MultistrategyHarness.t.sol";
import { Errors } from "src/infra/libraries/Errors.sol";

contract ReportLoss_Integration_Concrete_Test is MultistrategyHarness_Integration_Shared_Test {
    address strategy;
    function test_RevertWhen_StrategyZeroAddress() external {
        strategy = address(0);
        // Expect a revert
        vm.expectRevert(abi.encodeWithSelector(Errors.InvalidStrategyLoss.selector));
        multistrategyHarness.reportLoss(strategy, 100 ether);
    }

    modifier whenNotZeroAddress() {
        strategy = deployMockStrategyAdapter(address(multistrategyHarness), IERC4626(address(multistrategyHarness)).asset());
        _;
    }

    function test_RevertWhen_NotActiveStrategy()
        external
        whenNotZeroAddress
    {
        // Expect a revert
        vm.expectRevert(abi.encodeWithSelector(Errors.InvalidStrategyLoss.selector));
        multistrategyHarness.reportLoss(strategy, 100 ether);
    }

    modifier whenActiveStrategy() {
        multistrategyHarness.addStrategy(strategy, 5_000, 100 ether, 100_000 ether);
        _;
    }

    function test_RevertWhen_ReportedLossHigherThanDebt()
        external
        whenNotZeroAddress
        whenActiveStrategy
    {
        // Expect a revert
        vm.expectRevert(abi.encodeWithSelector(Errors.InvalidStrategyLoss.selector));
        multistrategyHarness.reportLoss(strategy, 100 ether);
    }

    modifier whenLossLowerThanDebt() {
        // Deposit into the multistrategy, so the strategy can request a credit
        triggerUserDeposit(users.bob, 1000 ether);
        // Request a credit
        IStrategyAdapter(strategy).requestCredit();
        _;
    }

    function test_ReportLoss_ReportZeroLoss() 
        external
        whenNotZeroAddress
        whenActiveStrategy
        whenLossLowerThanDebt
    {
        // Report a zero loss
        multistrategyHarness.reportLoss(strategy, 0);

        uint256 actualStrategyTotalLoss = multistrategyHarness.getStrategyParameters(strategy).totalLoss;
        uint256 expectedStrategyTotalLoss = 0;
        assertEq(actualStrategyTotalLoss, expectedStrategyTotalLoss, "reportLoss strat totalLoss");

        uint256 actualStrategyTotalDebt = multistrategyHarness.getStrategyParameters(strategy).totalDebt;
        uint256 expectedStrategyTotalDebt = 500 ether;
        assertEq(actualStrategyTotalDebt, expectedStrategyTotalDebt, "reportLoss strate totalDebt");

        uint256 actualMultistrategyTotalDebt = multistrategyHarness.totalDebt();
        uint256 expectedMultistrategyTotalDebt = 500 ether;
        assertEq(actualMultistrategyTotalDebt, expectedMultistrategyTotalDebt, "reportLoss multistrat totalDebt");
    }

    modifier whenLossGreaterThanZero() {
        _;
    }

    function test_ReportLoss()
        external
        whenNotZeroAddress
        whenActiveStrategy
        whenLossLowerThanDebt  
        whenLossGreaterThanZero
    {
        uint256 reportedLoss = 100 ether;

        // Report a zero loss
        multistrategyHarness.reportLoss(strategy, reportedLoss);

        uint256 actualStrategyTotalLoss = multistrategyHarness.getStrategyParameters(strategy).totalLoss;
        uint256 expectedStrategyTotalLoss = reportedLoss;
        assertEq(actualStrategyTotalLoss, expectedStrategyTotalLoss, "reportLoss strat totalLoss");

        uint256 actualStrategyTotalDebt = multistrategyHarness.getStrategyParameters(strategy).totalDebt;
        uint256 expectedStrategyTotalDebt = 400 ether;
        assertEq(actualStrategyTotalDebt, expectedStrategyTotalDebt, "reportLoss strate totalDebt");

        uint256 actualMultistrategyTotalDebt = multistrategyHarness.totalDebt();
        uint256 expectedMultistrategyTotalDebt = 400 ether;
        assertEq(actualMultistrategyTotalDebt, expectedMultistrategyTotalDebt, "reportLoss multistrat totalDebt");
    }
}