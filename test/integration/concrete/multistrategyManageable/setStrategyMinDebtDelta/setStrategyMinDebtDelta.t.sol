// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.20 <0.9.0;

import { Multistrategy_Integration_Shared_Test } from "../../../shared/Multistrategy.t.sol";
import { Errors } from "src/infra/libraries/Errors.sol";

contract SetStrategyMinDebtDelta_Integration_Concrete_Test is Multistrategy_Integration_Shared_Test {

    address strategy;
    uint256 minDebtDelta;

    function test_RevertWhen_CallerNotManager() external {
        // Change caller to bob
        swapCaller(users.bob);

        strategy = makeAddr("strategy");
        
        // Expect a revert
        vm.expectRevert(abi.encodeWithSelector(Errors.CallerNotManager.selector, users.bob));
        multistrategy.setStrategyMinDebtDelta(strategy, minDebtDelta);
    }

    modifier whenCallerIsManager() {
        swapCaller(users.keeper);
        _;
    }

    function test_RevertWhen_StrategyIsNotActive() external whenCallerIsManager {
        // Create address for a strategy that wont be activated
        strategy = makeAddr("strategy");

        // Expect Revert
        vm.expectRevert(abi.encodeWithSelector(Errors.StrategyNotActive.selector, strategy));
        multistrategy.setStrategyMinDebtDelta(strategy, minDebtDelta);
    }

    /// @dev Add a mock strategy to the multistrategy
    modifier whenStrategyIsActive() {
        strategy = deployMockStrategyWrapper(address(multistrategy), multistrategy.depositToken());
        uint256 debtRatio = 5_000;
        minDebtDelta = 100 ether;
        uint256 maxDebtDelta = 100_000 ether;

        multistrategy.addStrategy(strategy, debtRatio, minDebtDelta, maxDebtDelta);
        _;
    }

    function test_RevertWhen_MinDebtDeltaHigherThanMaxDebtDelta()
        external
        whenCallerIsManager
        whenStrategyIsActive
    {
        // Max debt delta is 100K so this is higher
        minDebtDelta = 200_000 ether;

        // Expect it to revert
        vm.expectRevert(abi.encodeWithSelector(Errors.InvalidDebtDelta.selector));
        multistrategy.setStrategyMinDebtDelta(strategy, minDebtDelta);
    }

    // Le = lower or equal
    modifier whenMinDebtDeltaLeMaxDebtDelta() {
        // Max debt delta is 100K so this is lower
        minDebtDelta = 100 ether;
        _;
    }

    function test_SetStrategyMinDebtDelta_NewMinDebtDelta() 
        external
        whenCallerIsManager
        whenStrategyIsActive
        whenMinDebtDeltaLeMaxDebtDelta
    {
        vm.expectEmit({ emitter: address(multistrategy) });
        emit StrategyMinDebtDeltaSet(strategy, minDebtDelta);

        multistrategy.setStrategyMinDebtDelta(strategy, minDebtDelta);

        uint256 actualStrategyMinDebtDelta = multistrategy.getStrategyParameters(strategy).minDebtDelta;
        uint256 expectedStrategyMinDebtDelta = minDebtDelta;
        assertEq(actualStrategyMinDebtDelta, expectedStrategyMinDebtDelta, "setMinDebtDelta"); 
    }
}