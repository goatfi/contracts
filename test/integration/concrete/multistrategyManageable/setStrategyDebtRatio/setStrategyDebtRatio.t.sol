// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.20 <0.9.0;

import { IERC4626, Multistrategy_Integration_Shared_Test } from "../../../shared/Multistrategy.t.sol";
import { StrategyAdapterMock } from "../../../../mocks/StrategyAdapterMock.sol";
import { Errors } from "src/infra/libraries/Errors.sol";

contract SetStrategyDebtRatio_Integration_Concrete_Test is Multistrategy_Integration_Shared_Test {

    StrategyAdapterMock strategy;
    uint256 debtRatio;

    function test_RevertWhen_CallerNotManager() external {
        // Change caller to bob
        swapCaller(users.bob);
        
        // Expect a revert
        vm.expectRevert(abi.encodeWithSelector(Errors.CallerNotManager.selector, users.bob));
        multistrategy.setStrategyDebtRatio(makeAddr("strategy"), debtRatio);
    }

    modifier whenCallerIsManager() {
        swapCaller(users.keeper);
        _;
    }

    function test_RevertWhen_StrategyIsNotActive() external whenCallerIsManager {
        // Expect Revert
        vm.expectRevert(abi.encodeWithSelector(Errors.StrategyNotActive.selector, makeAddr("strategy")));
        multistrategy.setStrategyDebtRatio(makeAddr("strategy"), debtRatio);
    }

    /// @dev Add a mock strategy to the multistrategy
    modifier whenStrategyIsActive() {
        strategy = deployMockStrategyAdapter(address(multistrategy), IERC4626(address(multistrategy)).asset());
        debtRatio = 5_000;
        uint256 minDebtDelta = 100 ether;
        uint256 maxDebtDelta = 100_000 ether;

        swapCaller(users.owner); multistrategy.addStrategy(address(strategy), debtRatio, minDebtDelta, maxDebtDelta);
        swapCaller(users.keeper);
        _;
    }

    function test_RevertWhen_DebtRatioAboveMaximum()
        external
        whenCallerIsManager
        whenStrategyIsActive
    {   
        // Debt ratio will be 110%, that is above the maximum (100%)
        debtRatio = 11_000;

        vm.expectRevert(abi.encodeWithSelector(Errors.DebtRatioAboveMaximum.selector, debtRatio));
        multistrategy.setStrategyDebtRatio(address(strategy), debtRatio);
    }

    modifier whenDebtRatioBelowMaximum() {
        // The multistrategy only has 1 active strategy, so this will be below minimum
        debtRatio = 6_000;
        _;
    }

    function test_SetStrategyDebtRatio_SetNewDebtRatio()
        external
        whenCallerIsManager
        whenStrategyIsActive
        whenDebtRatioBelowMaximum
    {   
        // Expect the relevant event
        vm.expectEmit({ emitter: address(multistrategy) });
        emit StrategyDebtRatioSet(address(strategy), debtRatio);

        multistrategy.setStrategyDebtRatio(address(strategy), debtRatio);

        // Assert the strategy debt ratio has been set
        uint256 actualStrategyDebtRatio = multistrategy.getStrategyParameters(address(strategy)).debtRatio;
        uint256 expectedStrategyDebtRatio = debtRatio;
        assertEq(actualStrategyDebtRatio, expectedStrategyDebtRatio, "setStrategyDebtRatio strategy debt ratio");

        // Assert the multistrategy debt ratio has been set
        uint256 actualMultistrategyDebtRatio = multistrategy.debtRatio();
        uint256 expectedMultistrategyDebtRatio = debtRatio;
        assertEq(actualMultistrategyDebtRatio, expectedMultistrategyDebtRatio, "setStrategyDebtRatio multistrategy debt ratio");
    }
}