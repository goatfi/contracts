// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.20 <0.9.0;

import { Multistrategy_Integration_Shared_Test } from "../../../shared/Multistrategy.t.sol";
import { IStrategyAdapter } from "interfaces/infra/multistrategy/IStrategyAdapter.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";
import { Errors } from "src/infra/libraries/Errors.sol";

interface IStrategyAdapterSlippage is IStrategyAdapter {
    function setStakingSlippage(uint256 slippage) external;
}

contract Withdraw_Integration_Concrete_Test is Multistrategy_Integration_Shared_Test {
    uint256 depositAmount = 1000 ether;
    uint256 amountToWithdraw;

    // Addresses for the mock strategies
    address strategy_one;
    address strategy_two;

    function test_RevertWhen_ContractIsPaused() external {
        // Pause the multistrategy
        multistrategy.pause();

        // Expect a revert
        vm.expectRevert(abi.encodeWithSelector(Pausable.EnforcedPause.selector));
        multistrategy.requestCredit();
    }

    modifier whenContractNotPaused() {
        _;
    }

    function test_RevertWhen_CallerNotEnoughSharesToCoverWithdraw() external {
        amountToWithdraw = 1000 ether;

        // Expect a revert
        vm.expectRevert(abi.encodeWithSelector(Errors.InsufficientBalance.selector, 0, amountToWithdraw));
        multistrategy.withdraw(amountToWithdraw);
    }

    modifier whenHasCallerEnoughSharesToCoverWithdraw() {
        triggerUserDeposit(users.bob, depositAmount);
        _;
    }

    function test_RevertWhen_AmountIsZero()
        external
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

    modifier whenMultistrategyBalanceLowerThanWithdrawAmount() {
        strategy_one = deployMockStrategyAdapter(address(multistrategy), multistrategy.baseAsset());
        strategy_two = deployMockStrategyAdapterSlippage(address(multistrategy), multistrategy.baseAsset());
        multistrategy.addStrategy(strategy_one, 5_000, 0, 100_000 ether);
        multistrategy.addStrategy(strategy_two, 2_000, 0, 100_000 ether);

        IStrategyAdapter(strategy_one).requestCredit();
        IStrategyAdapter(strategy_two).requestCredit();
        _;
    }

    function test_RevertWhen_SlippageOnWithdrawGreaterThanSlippageLimit() 
        external
        whenContractNotPaused
        whenHasCallerEnoughSharesToCoverWithdraw
        whenAmountGreaterThanZero
        whenMultistrategyBalanceLowerThanWithdrawAmount
    {
        IStrategyAdapterSlippage(strategy_two).setStakingSlippage(5_000);

        amountToWithdraw = 1000 ether;
        swapCaller(users.bob);

        // Expect a revert
        vm.expectRevert(abi.encodeWithSelector(Errors.SlippageCheckFailed.selector, 200 ether, 100 ether));
        multistrategy.withdraw(amountToWithdraw);
    }

    modifier whenWithdrawOrderEndReached() {
        _;
    }

    modifier whenNotEnoughBalanceToCoverWithdraw() {
        // Remove slippage protecction
        IStrategyAdapterSlippage(strategy_two).setSlippageLimit(10_000);
        // Set the staking slippage to 50%. If a user wants to withdram 1000 tokens, the staking
        // will only return 500 tokens
        IStrategyAdapterSlippage(strategy_two).setStakingSlippage(5_000);
        _;
    }

    /// @dev Test case where it reaches the end of the withdraw queue but it doesn't
    /// have enough funds to cover the withdraw.
    function test_Withdraw_QueueEndNoBalanceToCoverWithdraw() 
        external
        whenContractNotPaused
        whenHasCallerEnoughSharesToCoverWithdraw
        whenAmountGreaterThanZero
        whenMultistrategyBalanceLowerThanWithdrawAmount
        whenWithdrawOrderEndReached
        whenNotEnoughBalanceToCoverWithdraw
    {
        // If the user wants to withdraw everything from the multistrategy, the end of the queue will be hit
        amountToWithdraw = 1000 ether;

        swapCaller(users.bob);
        multistrategy.withdraw(amountToWithdraw);

        // Assert the user balance
        uint256 actualUserBalance = dai.balanceOf(users.bob);
        uint256 expectedUserBalance = 900 ether;
        assertEq(actualUserBalance, expectedUserBalance, "withdraw, user balance");

        // Assert the user shares balance
        uint256 actualUserSharesBalance = IERC20(address(multistrategy)).balanceOf(users.bob);
        uint256 expectedUserSharesBalance = 100 ether;
        assertEq(actualUserSharesBalance, expectedUserSharesBalance, "withdraw, user shares balance");

        // Assert multistrategy reserves.
        uint256 actualMultistrategyBalance = dai.balanceOf(address(multistrategy));
        uint256 expectedMultistrategyBalance = 0;
        assertEq(actualMultistrategyBalance, expectedMultistrategyBalance, "withdraw, multistrategy balance");

        // Assert strategy_one assets.
        uint256 actualStrategyOneAssets = IStrategyAdapter(strategy_one).totalAssets();
        uint256 expectedStrategyOneAssets = 0;
        assertEq(actualStrategyOneAssets, expectedStrategyOneAssets, "withdraw, strategy one assets");

        // Assert strategy_two assets.
        uint256 actualStrategyTwoAssets = IStrategyAdapter(strategy_two).totalAssets();
        uint256 expectedStrategyTwoAssets = 0;
        assertEq(actualStrategyTwoAssets, expectedStrategyTwoAssets, "withdraw, strategy two assets");

        // Assert multisrategy totalDebt
        uint256 actualMultistrategyDebt = multistrategy.totalDebt();
        uint256 expectedMultistrategyDebt = 100 ether;
        assertEq(actualMultistrategyDebt, expectedMultistrategyDebt, "withdraw, multistrategy total debt");

        // Assert strategy_one totalDebt
        uint256 actualStrategyOneDebt = multistrategy.getStrategyParameters(strategy_one).totalDebt;
        uint256 expectedStrategyOneDebt = 0;
        assertEq(actualStrategyOneDebt, expectedStrategyOneDebt, "withdraw, strategy one debt");

        // Assert strategy_two totalDebt
        uint256 actualStrategyTwoDebt = multistrategy.getStrategyParameters(strategy_two).totalDebt;
        uint256 expectedStrategyTwoDebt = 100 ether;
        assertEq(actualStrategyTwoDebt, expectedStrategyTwoDebt, "withdraw, strategy two debt");
    }

    /// @dev Test case where it reaches the end of the withdraw queue and it has enough
    /// funds to cover the withdraw
    function test_Withdraw_QueueEnd() 
        external
        whenContractNotPaused
        whenHasCallerEnoughSharesToCoverWithdraw
        whenAmountGreaterThanZero
        whenMultistrategyBalanceLowerThanWithdrawAmount
        whenWithdrawOrderEndReached
    {
        amountToWithdraw = 1000 ether;

        swapCaller(users.bob);
        multistrategy.withdraw(amountToWithdraw);

        // Assert the user balance
        uint256 actualUserBalance = dai.balanceOf(users.bob);
        uint256 expectedUserBalance = amountToWithdraw;
        assertEq(actualUserBalance, expectedUserBalance, "withdraw, user balance");

        // Assert the user shares balance
        uint256 actualUserSharesBalance = IERC20(address(multistrategy)).balanceOf(users.bob);
        uint256 expectedUserSharesBalance = depositAmount - amountToWithdraw;
        assertEq(actualUserSharesBalance, expectedUserSharesBalance, "withdraw, user shares balance");

        // Assert multistrategy reserves.
        uint256 actualMultistrategyBalance = dai.balanceOf(address(multistrategy));
        uint256 expectedMultistrategyBalance = 0;
        assertEq(actualMultistrategyBalance, expectedMultistrategyBalance, "withdraw, multistrategy balance");

        // Assert strategy_one assets.
        uint256 actualStrategyOneAssets = IStrategyAdapter(strategy_one).totalAssets();
        uint256 expectedStrategyOneAssets = 0;
        assertEq(actualStrategyOneAssets, expectedStrategyOneAssets, "withdraw, strategy one assets");

        // Assert strategy_two assets.
        uint256 actualStrategyTwoAssets = IStrategyAdapter(strategy_two).totalAssets();
        uint256 expectedStrategyTwoAssets = 0;
        assertEq(actualStrategyTwoAssets, expectedStrategyTwoAssets, "withdraw, strategy two assets");

        // Assert multisrategy totalDebt
        uint256 actualMultistrategyDebt = multistrategy.totalDebt();
        uint256 expectedMultistrategyDebt = depositAmount - amountToWithdraw;
        assertEq(actualMultistrategyDebt, expectedMultistrategyDebt, "withdraw, multistrategy total debt");

        // Assert strategy_one totalDebt
        uint256 actualStrategyOneDebt = multistrategy.getStrategyParameters(strategy_one).totalDebt;
        uint256 expectedStrategyOneDebt = 0;
        assertEq(actualStrategyOneDebt, expectedStrategyOneDebt, "withdraw, strategy one debt");

        // Assert strategy_two totalDebt
        uint256 actualStrategyTwoDebt = multistrategy.getStrategyParameters(strategy_two).totalDebt;
        uint256 expectedStrategyTwoDebt = 0 ether;
        assertEq(actualStrategyTwoDebt, expectedStrategyTwoDebt, "withdraw, strategy two debt");
    }

    /// @dev Test case where the withdraw process is started and it gets
    // enough funds to cover the withdraw without reaching the queue end
    function test_Withdraw_NotReachQueueEnd()
        external
        whenContractNotPaused
        whenHasCallerEnoughSharesToCoverWithdraw
        whenAmountGreaterThanZero
        whenMultistrategyBalanceLowerThanWithdrawAmount
    {
        amountToWithdraw = 800 ether;

        swapCaller(users.bob);
        multistrategy.withdraw(amountToWithdraw);

        // Assert the user balance
        uint256 actualUserBalance = dai.balanceOf(users.bob);
        uint256 expectedUserBalance = amountToWithdraw;
        assertEq(actualUserBalance, expectedUserBalance, "withdraw, user balance");

        // Assert the user shares balance
        uint256 actualUserSharesBalance = IERC20(address(multistrategy)).balanceOf(users.bob);
        uint256 expectedUserSharesBalance = depositAmount - amountToWithdraw;
        assertEq(actualUserSharesBalance, expectedUserSharesBalance, "withdraw, user shares balance");

        // Assert multistrategy reserves.
        uint256 actualMultistrategyBalance = dai.balanceOf(address(multistrategy));
        uint256 expectedMultistrategyBalance = 0;
        assertEq(actualMultistrategyBalance, expectedMultistrategyBalance, "withdraw, multistrategy balance");

        // Assert strategy_one assets
        uint256 actualStrategyOneAssets = IStrategyAdapter(strategy_one).totalAssets();
        uint256 expectedStrategyOneAssets = 0;
        assertEq(actualStrategyOneAssets, expectedStrategyOneAssets, "withdraw, strategy one assets");

        // Assert strategy_two assets
        uint256 actualStrategyTwoAssets = IStrategyAdapter(strategy_two).totalAssets();
        uint256 expectedStrategyTwoAssets = 200 ether;
        assertEq(actualStrategyTwoAssets, expectedStrategyTwoAssets, "withdraw, strategy two assets");

        // Assert multisrategy totalDebt
        uint256 actualMultistrategyDebt = multistrategy.totalDebt();
        uint256 expectedMultistrategyDebt = depositAmount - amountToWithdraw;
        assertEq(actualMultistrategyDebt, expectedMultistrategyDebt, "withdraw, multistrategy total debt");

        // Assert strategy_one totalDebt
        uint256 actualStrategyOneDebt = multistrategy.getStrategyParameters(strategy_one).totalDebt;
        uint256 expectedStrategyOneDebt = 0;
        assertEq(actualStrategyOneDebt, expectedStrategyOneDebt, "withdraw, strategy one debt");

        // Assert strategy_two totalDebt
        uint256 actualStrategyTwoDebt = multistrategy.getStrategyParameters(strategy_two).totalDebt;
        uint256 expectedStrategyTwoDebt = 200 ether;
        assertEq(actualStrategyTwoDebt, expectedStrategyTwoDebt, "withdraw, strategy two debt");
    }

    modifier whenMultistrategyBalanceHigherOrEqualThanWithdrawAmount() {
        strategy_one = deployMockStrategyAdapter(address(multistrategy), multistrategy.baseAsset());
        multistrategy.addStrategy(strategy_one, 5_000, 0, 100_000 ether);

        IStrategyAdapter(strategy_one).requestCredit();
        _;
    }

    /// @dev Test case where withdraws can be covered by the reserves in the multistrategy contract
    function test_Withdraw_NoWithdrawProcess() 
        external
        whenContractNotPaused
        whenHasCallerEnoughSharesToCoverWithdraw
        whenAmountGreaterThanZero
        whenMultistrategyBalanceHigherOrEqualThanWithdrawAmount
    {
        amountToWithdraw = 500 ether;

        swapCaller(users.bob);
        multistrategy.withdraw(amountToWithdraw);

        // Assert the user balance
        uint256 actualUserBalance = dai.balanceOf(users.bob);
        uint256 expectedUserBalance = amountToWithdraw;
        assertEq(actualUserBalance, expectedUserBalance, "withdraw, user balance");

        // Assert the user shares balance
        uint256 actualUserSharesBalance = IERC20(address(multistrategy)).balanceOf(users.bob);
        uint256 expectedUserSharesBalance = depositAmount - amountToWithdraw;
        assertEq(actualUserSharesBalance, expectedUserSharesBalance, "withdraw, user shares balance");

        // Assert multistrategy reserves
        uint256 actualMultistrategyBalance = dai.balanceOf(address(multistrategy));
        uint256 expectedMultistrategyBalance = 0;
        assertEq(actualMultistrategyBalance, expectedMultistrategyBalance, "withdraw, multistrategy balance");

        // Assert strategy_one assets
        uint256 actualStrategyOneAssets = IStrategyAdapter(strategy_one).totalAssets();
        uint256 expectedStrategyOneAssets = 500 ether;
        assertEq(actualStrategyOneAssets, expectedStrategyOneAssets, "withdraw, strategy one assets");

        // Assert multisrategy totalDebt
        uint256 actualMultistrategyDebt = multistrategy.totalDebt();
        uint256 expectedMultistrategyDebt = depositAmount - amountToWithdraw;
        assertEq(actualMultistrategyDebt, expectedMultistrategyDebt, "withdraw, multistrategy total debt");

        // Assert strategy_one totalDebt
        uint256 actualStrategyOneDebt = multistrategy.getStrategyParameters(strategy_one).totalDebt;
        uint256 expectedStrategyOneDebt = 500 ether;
        assertEq(actualStrategyOneDebt, expectedStrategyOneDebt, "withdraw, strategy one debt");
    }
}