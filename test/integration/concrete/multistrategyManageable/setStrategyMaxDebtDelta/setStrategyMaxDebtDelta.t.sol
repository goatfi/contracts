// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.20 <0.9.0;

import { Multistrategy_Integration_Shared_Test } from "../../../shared/Multistrategy.t.sol";
import { Errors } from "src/infra/libraries/Errors.sol";

contract SetStrategyMaxDebtDelta_Integration_Concrete_Test is Multistrategy_Integration_Shared_Test {

    address strategy;
    uint256 maxDebtDelta;

    function test_RevertWhen_CallerNotManager() external {
        // Change caller to bob
        swapCaller(users.bob);

        strategy = makeAddr("strategy");
        
        // Expect a revert
        vm.expectRevert(abi.encodeWithSelector(Errors.CallerNotManager.selector, users.bob));
        multistrategy.setStrategyMaxDebtDelta(strategy, maxDebtDelta);
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
        multistrategy.setStrategyMaxDebtDelta(strategy, maxDebtDelta);
    }

    /// @dev Add a mock strategy to the multistrategy
    modifier whenStrategyIsActive() {
        strategy = deployMockStrategyAdapter(address(multistrategy), multistrategy.depositToken());
        uint256 debtRatio = 5_000;
        uint256 minDebtDelta = 100 ether;
        maxDebtDelta = 100_000 ether;

        multistrategy.addStrategy(strategy, debtRatio, minDebtDelta, maxDebtDelta);
        _;
    }

    function test_RevertWhen_MaxDebtDeltaLowerThanMinDebtDelta()
        external
        whenCallerIsManager
        whenStrategyIsActive
    {
        // Min debt delta is 100 so this is lower
        maxDebtDelta = 10 ether;

        // Expect it to revert
        vm.expectRevert(abi.encodeWithSelector(Errors.InvalidDebtDelta.selector));
        multistrategy.setStrategyMaxDebtDelta(strategy, maxDebtDelta);
    }

    // Ge = greater or equal
    modifier whenMaxDebtDeltaGeMinDebtDelta() {
        // Min debt delta is 100 so this is higher
        maxDebtDelta = 100_000 ether;
        _;
    }

    function test_SetStrategyMaxDebtDelta_NewMaxDebtDelta() 
        external
        whenCallerIsManager
        whenStrategyIsActive
        whenMaxDebtDeltaGeMinDebtDelta
    {
        vm.expectEmit({ emitter: address(multistrategy) });
        emit StrategyMaxDebtDeltaSet(strategy, maxDebtDelta);

        multistrategy.setStrategyMaxDebtDelta(strategy, maxDebtDelta);

        uint256 actualStrategyMaxDebtDelta = multistrategy.getStrategyParameters(strategy).maxDebtDelta;
        uint256 expectedStrategyMaxDebtDelta = maxDebtDelta;
        assertEq(actualStrategyMaxDebtDelta, expectedStrategyMaxDebtDelta, "setMaxDebtDelta"); 
    }
}