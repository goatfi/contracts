// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.20 <0.9.0;

import { IERC4626, Multistrategy_Integration_Shared_Test } from "../../../shared/Multistrategy.t.sol";
import { StrategyAdapterMock } from "../../../../mocks/StrategyAdapterMock.sol";
import { Errors } from "src/infra/libraries/Errors.sol";

contract SetStrategyMaxDebtDelta_Integration_Concrete_Test is Multistrategy_Integration_Shared_Test {

    StrategyAdapterMock strategy;
    uint256 maxDebtDelta;

    function test_RevertWhen_CallerNotManager() external {
        // Change caller to bob
        swapCaller(users.bob);
        
        // Expect a revert
        vm.expectRevert(abi.encodeWithSelector(Errors.CallerNotManager.selector, users.bob));
        multistrategy.setStrategyMaxDebtDelta(makeAddr("strategy"), maxDebtDelta);
    }

    modifier whenCallerIsManager() {
        swapCaller(users.keeper);
        _;
    }

    function test_RevertWhen_StrategyIsNotActive() external whenCallerIsManager {

        // Expect Revert
        vm.expectRevert(abi.encodeWithSelector(Errors.StrategyNotActive.selector, makeAddr("strategy")));
        multistrategy.setStrategyMaxDebtDelta(makeAddr("strategy"), maxDebtDelta);
    }

    /// @dev Add a mock strategy to the multistrategy
    modifier whenStrategyIsActive() {
        strategy = deployMockStrategyAdapter(address(multistrategy), IERC4626(address(multistrategy)).asset());
        uint256 debtRatio = 5_000;
        uint256 minDebtDelta = 100 ether;
        maxDebtDelta = 100_000 ether;

        swapCaller(users.owner); multistrategy.addStrategy(address(strategy), debtRatio, minDebtDelta, maxDebtDelta);
        swapCaller(users.keeper);
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
        multistrategy.setStrategyMaxDebtDelta(address(strategy), maxDebtDelta);
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
        emit StrategyMaxDebtDeltaSet(address(strategy), maxDebtDelta);

        multistrategy.setStrategyMaxDebtDelta(address(strategy), maxDebtDelta);

        uint256 actualStrategyMaxDebtDelta = multistrategy.getStrategyParameters(address(strategy)).maxDebtDelta;
        uint256 expectedStrategyMaxDebtDelta = maxDebtDelta;
        assertEq(actualStrategyMaxDebtDelta, expectedStrategyMaxDebtDelta, "setMaxDebtDelta"); 
    }
}