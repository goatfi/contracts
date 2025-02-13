// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.20 <0.9.0;

import { IERC4626, Multistrategy_Integration_Shared_Test } from "../../../shared/Multistrategy.t.sol";
import { StrategyAdapterMock } from "../../../../mocks/StrategyAdapterMock.sol";
import { Errors } from "src/infra/libraries/Errors.sol";

contract RetireStrategy_Integration_Concrete_Test is Multistrategy_Integration_Shared_Test {

    StrategyAdapterMock strategy;

    function test_RevertWhen_CallerNotManager() external {
        // Change caller to bob
        swapCaller(users.bob);
        
        // Expect a revert
        vm.expectRevert(abi.encodeWithSelector(Errors.CallerNotManager.selector, users.bob));
        multistrategy.retireStrategy(makeAddr("strategy"));
    }

    modifier whenCallerIsManager() {
        swapCaller(users.keeper);
        _;
    }

    function test_RevertWhen_StrategyIsNotActive() external whenCallerIsManager {
        // Expect Revert
        vm.expectRevert(abi.encodeWithSelector(Errors.StrategyNotActive.selector, makeAddr("strategy")));
        multistrategy.retireStrategy(makeAddr("strategy"));
    }

    /// @dev Add a mock strategy to the multistrategy
    modifier whenStrategyIsActive() {
        strategy = deployMockStrategyAdapter(address(multistrategy), IERC4626(address(multistrategy)).asset());
        uint256 debtRatio = 5_000;
        uint256 minDebtDelta = 100 ether;
        uint256 maxDebtDelta = 100_000 ether;

        swapCaller(users.owner); multistrategy.addStrategy(address(strategy), debtRatio, minDebtDelta, maxDebtDelta);
        swapCaller(users.keeper);
        _;
    }

    function test_RetireStrategy_RetireActiveStrategy()
        external
        whenCallerIsManager
        whenStrategyIsActive 
    {
        // Expect the relevant event
        vm.expectEmit({ emitter: address(multistrategy)});
        emit StrategyRetired(address(strategy));

        // Retire the strategy
        multistrategy.retireStrategy(address(strategy));

        uint256 actualMultistrategyDebtRatio = multistrategy.debtRatio();
        uint256 expectedMultistrategyDebtRatio = 0;
        assertEq(actualMultistrategyDebtRatio, expectedMultistrategyDebtRatio, "retire strategy multistrategy debt ratio");

        uint256 actualStrategyDebtRatio = multistrategy.getStrategyParameters(address(strategy)).debtRatio;
        uint256 expectedStrategyDebtRatio = 0;
        assertEq(actualStrategyDebtRatio, expectedStrategyDebtRatio, "retire strategy strategy debt ratio");
    }

    modifier whenStrategyIsRetired() {
        multistrategy.retireStrategy(address(strategy));
        _;
    }

    /// @dev Note that a strategy can be active and retired at the same time.
    ///      Retiring a strategy means we don't want any further deposits into the strategy
    ///      and only withdraws and debt repayments are permitted. So once we retire a strategy
    ///      it is active as it still can hold funds.
    function test_RetireStrategy_RetireAlreadyRetiredStrategy()
        external
        whenCallerIsManager
        whenStrategyIsActive
        whenStrategyIsRetired
    {
        // Expect the relevant event
        vm.expectEmit({ emitter: address(multistrategy)});
        emit StrategyRetired(address(strategy));

        // Retire the strategy
        multistrategy.retireStrategy(address(strategy));

        uint256 actualMultistrategyDebtRatio = multistrategy.debtRatio();
        uint256 expectedMultistrategyDebtRatio = 0;
        assertEq(actualMultistrategyDebtRatio, expectedMultistrategyDebtRatio, "retire strategy multistrategy debt ratio");

        uint256 actualStrategyDebtRatio = multistrategy.getStrategyParameters(address(strategy)).debtRatio;
        uint256 expectedStrategyDebtRatio = 0;
        assertEq(actualStrategyDebtRatio, expectedStrategyDebtRatio, "retire strategy strategy debt ratio");
    }
}