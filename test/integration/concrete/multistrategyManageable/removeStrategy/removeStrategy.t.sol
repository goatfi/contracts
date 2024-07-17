// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.20 <0.9.0;

import { Multistrategy_Integration_Shared_Test } from "../../../shared/Multistrategy.t.sol";
import { IStrategyAdapter } from "interfaces/infra/multistrategy/IStrategyAdapter.sol";
import { Errors } from "src/infra/libraries/Errors.sol";

contract RemoveStrategy_Integration_Concrete_Test is Multistrategy_Integration_Shared_Test {

    address strategy;

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

    function test_RevertWhen_StrategyHasOutstandingDebt() external whenCallerIsManager {
        // Deploy and add a mock strategy adapter in order to request a credit
        strategy = deployMockStrategyAdapter(address(multistrategy), multistrategy.baseAsset());
        multistrategy.addStrategy(strategy, 5_000, 0, 100_000 ether);

        // Deposit to the multistrategy so the strategy has funds to request a credit.
        triggerUserDeposit(users.bob, 1_000 ether);

        // Strategy requests a credit
        swapCaller(users.keeper);
        IStrategyAdapter(strategy).requestCredit();

        // Expect a revert when trying to remove the strategy from the withdraw order
        vm.expectRevert(abi.encodeWithSelector(Errors.StrategyWithOutstandingDebt.selector));
        multistrategy.removeStrategy(strategy);
    }

    modifier whenStrategyHasNoOutstandingDebt() {
        _;
    }

    function test_RevertWhen_StrategyIsNotInWithdrawOrder() 
        external 
        whenCallerIsManager
        whenStrategyHasNoOutstandingDebt
    {
        // Create address for a strategy that wont be activated
        strategy = makeAddr("strategy");

        // Expect Revert
        vm.expectRevert(abi.encodeWithSelector(Errors.StrategyNotFound.selector));
        multistrategy.removeStrategy(strategy);
    }

    /// @dev Add a mock strategy to the multistrategy
    modifier whenStrategyIsInWithdrawOrder() {
        strategy = deployMockStrategyAdapter(address(multistrategy), multistrategy.baseAsset());
        uint256 debtRatio = 5_000;
        uint256 minDebtDelta = 100 ether;
        uint256 maxDebtDelta = 100_000 ether;

        multistrategy.addStrategy(strategy, debtRatio, minDebtDelta, maxDebtDelta);
        _;
    }

    function test_RemoveStrategy_RemoveStrategyFromWithdrawOrder()
        external
        whenCallerIsManager
        whenStrategyHasNoOutstandingDebt
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
}