// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.20 <0.9.0;

import { IERC4626, Multistrategy_Integration_Shared_Test } from "../../../shared/Multistrategy.t.sol";
import { IStrategyAdapter } from "interfaces/infra/multistrategy/IStrategyAdapter.sol";
import { Errors } from "src/infra/libraries/Errors.sol";

contract RemoveStrategy_Integration_Concrete_Test is Multistrategy_Integration_Shared_Test {

    address strategy;
    address strategy_two;

    function test_RevertWhen_CallerNotManager() external {
        // Change caller to bob
        swapCaller(users.bob);

        strategy = makeAddr("strategy");
        
        // Expect a revert
        vm.expectRevert(abi.encodeWithSelector(Errors.CallerNotManager.selector, users.bob));
        multistrategy.removeStrategy(strategy);
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
        multistrategy.removeStrategy(strategy);
    }

    /// @dev Add a mock strategy to the multistrategy
    modifier whenStrategyIsActive() {
        strategy = deployMockStrategyAdapter(address(multistrategy), IERC4626(address(multistrategy)).asset());
        uint256 debtRatio = 5_000;
        uint256 minDebtDelta = 100 ether;
        uint256 maxDebtDelta = 100_000 ether;

        multistrategy.addStrategy(strategy, debtRatio, minDebtDelta, maxDebtDelta);
        _;
    }

    function test_RevertWhen_StrategyDebtRatioNotZero()
        external
        whenCallerIsManager
        whenStrategyIsActive
    {
        // Expect a revert when trying to remove the strategy from the withdraw order
        vm.expectRevert(abi.encodeWithSelector(Errors.StrategyNotRetired.selector));
        multistrategy.removeStrategy(strategy);
    }

    modifier whenStrategyDebtGreaterThanZero() {
        triggerUserDeposit(users.bob, 1000 ether);
        swapCaller(users.keeper);
        IStrategyAdapter(strategy).requestCredit();
        _;
    }

    modifier whenDebtRatioIsZero() {
        multistrategy.retireStrategy(strategy);
        _;
    }

    function test_RevertWhen_StrategyHasOutstandingDebt() 
        external 
        whenCallerIsManager
        whenStrategyIsActive
        whenStrategyDebtGreaterThanZero
        whenDebtRatioIsZero
    {
        // Expect a revert when trying to remove the strategy from the withdraw order
        vm.expectRevert(abi.encodeWithSelector(Errors.StrategyWithOutstandingDebt.selector));
        multistrategy.removeStrategy(strategy);
    }

    modifier whenStrategyHasNoDebt() {
        _;
    }

    function test_RevertWhen_StrategyIsNotInWithdrawOrder() 
        external 
        whenCallerIsManager
        whenStrategyIsActive
        whenDebtRatioIsZero
        whenStrategyHasNoDebt
    {
        // Create address for a strategy that wont be activated
        strategy = makeAddr("strategy");

        // Expect Revert
        vm.expectRevert(abi.encodeWithSelector(Errors.StrategyNotActive.selector, strategy));
        multistrategy.removeStrategy(strategy);
    }

    modifier whenStrategyIsInWithdrawOrder() {
        _;
    }

    function test_RemoveStrategy_RemoveStrategyFromWithdrawOrder()
        external
        whenCallerIsManager
        whenStrategyIsActive
        whenDebtRatioIsZero
        whenStrategyHasNoDebt
        whenStrategyIsInWithdrawOrder
    {
        // Expect the relevant event
        vm.expectEmit({ emitter: address(multistrategy)});
        emit StrategyRemoved(strategy);

        // Remove the strategy from withdraw order
        multistrategy.removeStrategy(strategy);
    
        bool isInWithdrawOrder;
        bool expectedInWithdrawOrder = false;

        // Check if the strategy is in the withdraw order array
        address[] memory actualWithdrawOrder = multistrategy.getWithdrawOrder();
        for(uint256 i = 0; i < actualWithdrawOrder.length; ++i) {
            if(actualWithdrawOrder[i] == strategy) {
                isInWithdrawOrder = true;
            }
        }
        
        // Assert it has been removed
        assertEq(isInWithdrawOrder, expectedInWithdrawOrder, "removeStrategy");

        address actualAddressAtWithdrawOrderPos0 = multistrategy.getWithdrawOrder()[0];
        address expectedAddressAtWithdrawOrderPos0 = address(0);
        // Assert that the strategy has been ordered
        assertEq(actualAddressAtWithdrawOrderPos0, expectedAddressAtWithdrawOrderPos0, "removeStrategy withdraw order");
    }

    /// @dev Add a mock strategy to the multistrategy
    modifier whenTwoActiveStrategies() {
        strategy_two = deployMockStrategyAdapter(address(multistrategy), IERC4626(address(multistrategy)).asset());
        uint256 debtRatio = 5_000;
        uint256 minDebtDelta = 100 ether;
        uint256 maxDebtDelta = 100_000 ether;

        multistrategy.addStrategy(strategy_two, debtRatio, minDebtDelta, maxDebtDelta);
        multistrategy.retireStrategy(strategy_two);
        _;
    }

    function test_RemoveStrategy_RemoveStrategyNotFirstInQueue()
        external
        whenCallerIsManager
        whenStrategyIsActive
        whenTwoActiveStrategies
        whenDebtRatioIsZero
        whenStrategyHasNoDebt
        whenStrategyIsInWithdrawOrder
    {
        // Expect the relevant event
        vm.expectEmit({ emitter: address(multistrategy)});
        emit StrategyRemoved(strategy_two);

        // Remove the strategy from withdraw order
        multistrategy.removeStrategy(strategy_two);
    
        bool isInWithdrawOrder;
        bool expectedInWithdrawOrder = false;

        // Check if the strategy is in the withdraw order array
        address[] memory actualWithdrawOrder = multistrategy.getWithdrawOrder();
        for(uint256 i = 0; i < actualWithdrawOrder.length; ++i) {
            if(actualWithdrawOrder[i] == strategy_two) {
                isInWithdrawOrder = true;
            }
        }
        
        // Assert it has been removed
        assertEq(isInWithdrawOrder, expectedInWithdrawOrder, "removeStrategy");

        address actualAddressAtWithdrawOrderPos0 = multistrategy.getWithdrawOrder()[1];
        address expectedAddressAtWithdrawOrderPos0 = address(0);
        // Assert that the strategy has been ordered
        assertEq(actualAddressAtWithdrawOrderPos0, expectedAddressAtWithdrawOrderPos0, "removeStrategy withdraw order");
    }
}