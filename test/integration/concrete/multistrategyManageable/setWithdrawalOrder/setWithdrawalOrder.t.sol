// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.20 <0.9.0;

import { Multistrategy_Integration_Shared_Test } from "../../../shared/Multistrategy.t.sol";
import { Errors } from "src/infra/libraries/Errors.sol";

contract SetWithdrawOrder_Integration_Concrete_Test is Multistrategy_Integration_Shared_Test {

    address[] strategies;
    uint256 debtRatio = 5_000;
    uint256 minDebtRatio = 100 ether;
    uint256 maxDebtRatio = 100_000 ether;

    function test_RevertWhen_CallerNotManager() external {
        // Change caller to bob
        swapCaller(users.bob);
        
        // Expect a revert
        vm.expectRevert(abi.encodeWithSelector(Errors.CallerNotManager.selector, users.bob));
        multistrategy.setWithdrawOrder(strategies);
    }

    modifier whenCallerIsManager() {
        swapCaller(users.keeper);
        _;
    }

    function test_RevertWhen_LengthDoNotMatch() external whenCallerIsManager {
        // Multistrategy withdrawOrder is length 10, so we create a length 11 to missmatch.
        strategies = new address[](11);

        // Expect it to revert
        vm.expectRevert(abi.encodeWithSelector(Errors.StrategiesLengthMissMatch.selector));
        multistrategy.setWithdrawOrder(strategies);
    }

    modifier whenLengthMatches() {
        _;
    }

    function test_RevertWhen_DuplicateStrategies()
        external
        whenCallerIsManager
        whenLengthMatches
    {   
        // Add a strategy to the multistrategy so it is present in the withdrawal order.
        address mockStrategy = deployMockStrategyWrapper(address(multistrategy), multistrategy.depositToken());
        multistrategy.addStrategy(mockStrategy, debtRatio, minDebtRatio, maxDebtRatio);
        
        // Create an array with duplicate strategies
        strategies = [
            mockStrategy, // 1
            mockStrategy, // 2
            address(0),   // 3
            address(0),   // 4
            address(0),   // 5
            address(0),   // 6
            address(0),   // 7
            address(0),   // 8
            address(0),   // 9
            address(0)    // 10
        ];

        // Expect it to revert
        vm.expectRevert(abi.encodeWithSelector(Errors.DuplicateStrategyInArray.selector));
        multistrategy.setWithdrawOrder(strategies);
    }

    modifier whenNoDuplicates() {
        _;
    }

    function test_RevertWhen_InactiveStrategy()
        external
        whenCallerIsManager
        whenLengthMatches
        whenNoDuplicates
    {
        // Create the strategy but we don't add it to the multistrategy, so it wont be active
        address mockStrategy = deployMockStrategyWrapper(address(multistrategy), multistrategy.depositToken());
        
        // Create an array with an inactive strategy
        strategies = [
            mockStrategy, // 1
            address(0),   // 2
            address(0),   // 3
            address(0),   // 4
            address(0),   // 5
            address(0),   // 6
            address(0),   // 7
            address(0),   // 8
            address(0),   // 9
            address(0)    // 10
        ];

        // Expect it to revert
        vm.expectRevert(abi.encodeWithSelector(Errors.StrategyNotActive.selector, mockStrategy));
        multistrategy.setWithdrawOrder(strategies);
    }

    modifier whenAllStrategiesAreActive() {
        _;
    }

    /// @dev SetWithdrawOrder is used to move withdrawing order, not to add
    /// a new strategy to the multistrategy, so if an address is added that isn't already
    /// present in the withdrawOrder, it should revert. As a strategy can only be added to
    /// the withdraw order via the addStrategy function.
    function test_RevertWhen_AddingAnExternalStrategy()
        external
        whenCallerIsManager
        whenLengthMatches
        whenNoDuplicates
        whenAllStrategiesAreActive
    {
        // Add a strategy to the multistrategy so it is present in the withdrawal order.
        address mockStrategy = deployMockStrategyWrapper(address(multistrategy), multistrategy.depositToken());
        multistrategy.addStrategy(mockStrategy, debtRatio, minDebtRatio, maxDebtRatio);

        // Remove it from the withdrawalOrder
        // Now the strategy is active, but removed from the withdrawal order. So including it
        // in the new withdrawal order is not permited.
        multistrategy.removeStrategy(mockStrategy);

        // Create an array with an external strategy
        strategies = [
            mockStrategy, // 1
            address(0),   // 2
            address(0),   // 3
            address(0),   // 4
            address(0),   // 5
            address(0),   // 6
            address(0),   // 7
            address(0),   // 8
            address(0),   // 9
            address(0)    // 10
        ];

        // Expect it to revert
        vm.expectRevert(abi.encodeWithSelector(Errors.StrategyNotFound.selector));
        multistrategy.setWithdrawOrder(strategies);
    }

    modifier whenNoExternalStrategiesAdded() {
        _;
    }

    /// @dev If a non-zeroAddress is placed after a zero address in the withdraw order
    /// it should revert, as that strategy wont be able to have withdraws, as the 
    /// withdraw function exits when it reaches a zero address
    function test_RevertWhen_ZeroAddressOrderNotRespected()
        external
        whenCallerIsManager
        whenLengthMatches
        whenNoDuplicates
        whenAllStrategiesAreActive
        whenNoExternalStrategiesAdded
    {
        // Add a strategy to the multistrategy so it is present in the withdrawal order.
        address mockStrategy = deployMockStrategyWrapper(address(multistrategy), multistrategy.depositToken());
        multistrategy.addStrategy(mockStrategy, debtRatio, minDebtRatio, maxDebtRatio);

        // Create an array with an invalid order
        strategies = [
            address(0),   // 1
            mockStrategy, // 2
            address(0),   // 3
            address(0),   // 4
            address(0),   // 5
            address(0),   // 6
            address(0),   // 7
            address(0),   // 8
            address(0),   // 9
            address(0)    // 10
        ];

        // Expect it to revert
        vm.expectRevert(abi.encodeWithSelector(Errors.InvalidWithdrawOrder.selector));
        multistrategy.setWithdrawOrder(strategies);
    }

    modifier whenZeroAddressOrderIsRespected() {
        _;
    }

    function test_SetWithdrawOrder_NewWithdrawOrder()
        external
        whenCallerIsManager
        whenLengthMatches
        whenNoDuplicates
        whenAllStrategiesAreActive
        whenNoExternalStrategiesAdded
        whenZeroAddressOrderIsRespected
    {
        // Add two strategies to the multistrategy so they are present in the withdrawOrder
        address mockStrategy_1 = deployMockStrategyWrapper(address(multistrategy), multistrategy.depositToken());
        address mockStrategy_2 = deployMockStrategyWrapper(address(multistrategy), multistrategy.depositToken());
        multistrategy.addStrategy(mockStrategy_1, debtRatio, minDebtRatio, maxDebtRatio);
        multistrategy.addStrategy(mockStrategy_2, debtRatio, minDebtRatio, maxDebtRatio);

        // Assert mock strategy 1 is in first position and mock strategy 2 is in second position
        address[] memory withdrawOrder = multistrategy.getWithdrawOrder();
        assertEq(withdrawOrder[0], mockStrategy_1, "withdraw order");
        assertEq(withdrawOrder[1], mockStrategy_2, "withdraw order");
        
        // Create a new withdraw order
        strategies = [
            mockStrategy_2, // 1
            mockStrategy_1, // 2
            address(0),   // 3
            address(0),   // 4
            address(0),   // 5
            address(0),   // 6
            address(0),   // 7
            address(0),   // 8
            address(0),   // 9
            address(0)    // 10
        ];

        vm.expectEmit({ emitter: address(multistrategy) });
        emit WithdrawOrderSet();

        multistrategy.setWithdrawOrder(strategies);

        withdrawOrder = multistrategy.getWithdrawOrder();

        // Assert the withdraw order has been set correctly
        address actualFirstPositionStrategy = withdrawOrder[0];
        address expectedFirstPositionStrategy = mockStrategy_2;
        assertEq(actualFirstPositionStrategy, expectedFirstPositionStrategy, "setWithdrawOrder");


        address actualSecondPositionStrategy = withdrawOrder[1];
        address expectedSecondPositionStrategy = mockStrategy_1;
        assertEq(actualSecondPositionStrategy, expectedSecondPositionStrategy, "setWithdrawOrder");
    }
}