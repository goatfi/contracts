// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.20 <0.9.0;

import { Multistrategy_Integration_Shared_Test } from "../../../shared/Multistrategy.t.sol";
import { IStrategyAdapter } from "interfaces/infra/multistrategy/IStrategyAdapter.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Errors } from "src/infra/libraries/Errors.sol";

contract Withdraw_Integration_Concrete_Test is Multistrategy_Integration_Shared_Test {
    uint256 depositAmount = 1000 ether;
    uint256 amountToWithdraw;

    // Addresses for the mock strategies
    address strategy_one;
    address strategy_two;

    modifier whenCalledByUser() {
        swapCaller(users.bob);
        _;
        swapCaller(users.owner);
    }

    function test_RevertWhen_CallerNotEnoughSharesToCoverWithdraw() external whenCalledByUser {
        amountToWithdraw = 1000 ether;

        // Expect a revert
        vm.expectRevert(abi.encodeWithSelector(Errors.InsufficientBalance.selector, 0, amountToWithdraw));
        multistrategy.withdraw(amountToWithdraw);
    }

    modifier whenHasCallerEnoughSharesToCoverWithdraw() {
        dai.mint(users.bob, depositAmount);
        swapCaller(users.bob);
        dai.approve(address(multistrategy), depositAmount);
        multistrategy.deposit(depositAmount);
        swapCaller(users.owner);
        _;
    }

    function test_RevertWhen_AmountIsZero()
        external
        whenCalledByUser
        whenHasCallerEnoughSharesToCoverWithdraw
    {
        amountToWithdraw = 0;

        // Expect a revert
        vm.expectRevert(abi.encodeWithSelector(Errors.ZeroAmount.selector, amountToWithdraw));
        multistrategy.withdraw(amountToWithdraw);
    }

    modifier whenAmountGreaterThanZero() {
        _;
    }

    /// @dev Case: Multistrategy with 2 strategies, 50% debt ratio the frist one, 30% ratio the second one.
    /// both request a credit. User will want to withdraw 1_000 tokens but only 200 will be available on the contract
    /// so it will have to withdraw from the strategies.
    modifier whenDepositTokenBalanceBelowWithdrawValue() {
        // Create and add Strategy 1
        strategy_one = deployMockStrategyAdapter(address(multistrategy), multistrategy.depositToken());
        multistrategy.addStrategy(strategy_one, 5_000, 0, 10_000 ether);

        // Create and add Strategy 2
        strategy_two = deployMockStrategyAdapter(address(multistrategy), multistrategy.depositToken());
        multistrategy.addStrategy(strategy_two, 3_000, 0, 10_000 ether);

        IStrategyAdapter(strategy_one).requestCredit();
        IStrategyAdapter(strategy_two).requestCredit();
        _;
    }

    /// @dev Case where withdraw value is higher than the contract balance, so it starts the withdraw
    /// process. After withdrawing from all strategies, there are not enough funds to cover
    /// the withdraw value.
    function test_Withdraw_WithdrawValueHigherThanMaximumWithdrawable()
        external
        whenHasCallerEnoughSharesToCoverWithdraw
        whenAmountGreaterThanZero
        whenDepositTokenBalanceBelowWithdrawValue
    {
        amountToWithdraw = IERC20(address(multistrategy)).balanceOf(users.bob);

        /// Remove the strategy from the withdraw order
        multistrategy.removeStrategy(strategy_two);

        swapCaller(users.bob);

        //Expect the relevant event to be emitted
        vm.expectEmit({emitter: address(multistrategy)});
        emit Withdraw(700 ether);

        multistrategy.withdraw(amountToWithdraw);

        // Assert we could only manage to withdraw the maximum withdrawable, shares representing those assets
        // not withdrawn won't be burned, as the users is still entitled to those assets
        uint256 actualWithdrawnAssets = dai.balanceOf(users.bob);
        uint256 expectedWithdrawnAssets = 700 ether;
        assertEq(actualWithdrawnAssets, expectedWithdrawnAssets, "withdraw, withdrawn assets");

        uint256 actualUserShares = IERC20(address(multistrategy)).balanceOf(users.bob);
        uint256 expectedUserShares = 300 ether;
        assertEq(actualUserShares, expectedUserShares, "withdraw, user shares");

        uint256 actualMultistrategyTotalAssets = multistrategy.totalAssets();
        uint256 expectedMultistrategyTotalAssets = 300 ether;
        assertEq(actualMultistrategyTotalAssets, expectedMultistrategyTotalAssets, "withdraw, totalAssets");

        // Assert that the strategies have the correct amount of tokens
        uint256 actualStrategyOneTotalAssets = IStrategyAdapter(strategy_one).totalAssets();
        uint256 expectedStrategyOneTotalAssets = 0;
        assertEq(actualStrategyOneTotalAssets, expectedStrategyOneTotalAssets, "withdraw, strategy_one balance");

        uint256 actualStrategyTwoTotalAssets = IStrategyAdapter(strategy_two).totalAssets();
        uint256 expectedStrategyTwoTotalAssets = 300 ether;
        assertEq(actualStrategyTwoTotalAssets, expectedStrategyTwoTotalAssets, "withdraw, strategy_two balance");
    }

    modifier whenWithdrawValueLowerThanMaximumWithdrawable() {
        _;
    }

    /// @dev Case where withdraw value is higher than the contract balance, so it starts the withdraw
    /// process. After withdrawing from all strategies, there are enough funds to cover the withdraw value.
    function test_Withdraw_WithdrawLoop()
        external
        whenHasCallerEnoughSharesToCoverWithdraw
        whenAmountGreaterThanZero
        whenDepositTokenBalanceBelowWithdrawValue
        whenWithdrawValueLowerThanMaximumWithdrawable
    {
        amountToWithdraw = IERC20(address(multistrategy)).balanceOf(users.bob);

        swapCaller(users.bob);

        //Expect the relevant event to be emitted
        vm.expectEmit({emitter: address(multistrategy)});
        emit Withdraw(amountToWithdraw);

        multistrategy.withdraw(amountToWithdraw);

        // Assert we could only manage to withdraw the maximum withdrawable, shares representing those assets
        // not withdrawn won't be burned, as the users is still entitled to those assets
        uint256 actualWithdrawnAssets = dai.balanceOf(users.bob);
        uint256 expectedWithdrawnAssets = amountToWithdraw;
        assertEq(actualWithdrawnAssets, expectedWithdrawnAssets, "withdraw, withdrawn assets");

        uint256 actualUserShares = IERC20(address(multistrategy)).balanceOf(users.bob);
        uint256 expectedUserShares = 0;
        assertEq(actualUserShares, expectedUserShares, "withdraw, user shares");

        uint256 actualMultistrategyTotalAssets = multistrategy.totalAssets();
        uint256 expectedMultistrategyTotalAssets = 0;
        assertEq(actualMultistrategyTotalAssets, expectedMultistrategyTotalAssets, "withdraw, totalAssets");

        // Assert that the strategies have the correct amount of tokens
        uint256 actualStrategyOneTotalAssets = IStrategyAdapter(strategy_one).totalAssets();
        uint256 expectedStrategyOneTotalAssets = 0;
        assertEq(actualStrategyOneTotalAssets, expectedStrategyOneTotalAssets, "withdraw, strategy_one balance");

        uint256 actualStrategyTwoTotalAssets = IStrategyAdapter(strategy_two).totalAssets();
        uint256 expectedStrategyTwoTotalAssets = 0;
        assertEq(actualStrategyTwoTotalAssets, expectedStrategyTwoTotalAssets, "withdraw, strategy_two balance");
    }

    modifier whenDepositTokenBalanceHigherOrEqualThanWithdrawValue() {
        // Create and add Strategy 1
        strategy_one = deployMockStrategyAdapter(address(multistrategy), multistrategy.depositToken());
        multistrategy.addStrategy(strategy_one, 2_000, 0, 10_000 ether);

        // Create and add Strategy 2
        strategy_two = deployMockStrategyAdapter(address(multistrategy), multistrategy.depositToken());
        multistrategy.addStrategy(strategy_two, 2_000, 0, 10_000 ether);

        IStrategyAdapter(strategy_one).requestCredit();
        IStrategyAdapter(strategy_two).requestCredit();
        _;
    }

    /// @dev Case where withdraw value is lower than the contract balance, so it can cover the withdraw without
    /// withdrawing from strategies.
    function test_Withdraw() 
        external
        whenHasCallerEnoughSharesToCoverWithdraw
        whenAmountGreaterThanZero
        whenDepositTokenBalanceHigherOrEqualThanWithdrawValue
    {
        amountToWithdraw = 500 ether;

        swapCaller(users.bob);

        //Expect the relevant event to be emitted
        vm.expectEmit({emitter: address(multistrategy)});
        emit Withdraw(amountToWithdraw);

        multistrategy.withdraw(amountToWithdraw);

        // Assert we could only manage to withdraw the maximum withdrawable, shares representing those assets
        // not withdrawn won't be burned, as the users is still entitled to those assets
        uint256 actualWithdrawnAssets = dai.balanceOf(users.bob);
        uint256 expectedWithdrawnAssets = amountToWithdraw;
        assertEq(actualWithdrawnAssets, expectedWithdrawnAssets, "withdraw, withdrawn assets");

        uint256 actualUserShares = IERC20(address(multistrategy)).balanceOf(users.bob);
        uint256 expectedUserShares = 500 ether;
        assertEq(actualUserShares, expectedUserShares, "withdraw, user shares");

        uint256 actualMultistrategyTotalAssets = multistrategy.totalAssets();
        uint256 expectedMultistrategyTotalAssets = 500 ether;
        assertEq(actualMultistrategyTotalAssets, expectedMultistrategyTotalAssets, "withdraw, totalAssets");

        // Assert that the strategies have the correct amount of tokens
        uint256 actualStrategyOneTotalAssets = IStrategyAdapter(strategy_one).totalAssets();
        uint256 expectedStrategyOneTotalAssets = 200 ether;
        assertEq(actualStrategyOneTotalAssets, expectedStrategyOneTotalAssets, "withdraw, strategy_one balance");

        uint256 actualStrategyTwoTotalAssets = IStrategyAdapter(strategy_two).totalAssets();
        uint256 expectedStrategyTwoTotalAssets = 200 ether;
        assertEq(actualStrategyTwoTotalAssets, expectedStrategyTwoTotalAssets, "withdraw, strategy_two balance");
    }
}