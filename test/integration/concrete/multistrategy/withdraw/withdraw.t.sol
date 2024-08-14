// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.20 <0.9.0;

import { IERC4626, Multistrategy_Integration_Shared_Test } from "../../../shared/Multistrategy.t.sol";
import { IStrategyAdapter } from "interfaces/infra/multistrategy/IStrategyAdapter.sol";
import { IStrategyAdapterMock } from "../../../../shared/TestInterfaces.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";
import { Errors } from "src/infra/libraries/Errors.sol";

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
        vm.expectRevert(abi.encodeWithSelector(Errors.ERC4626ExceededMaxWithdraw.selector, users.bob, amountToWithdraw, 0));
        IERC4626(address(multistrategy)).withdraw(amountToWithdraw, users.bob, users.bob);
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
        IERC4626(address(multistrategy)).withdraw(amountToWithdraw, users.bob, users.bob);
    }

    modifier whenAmountGreaterThanZero() {
        _;
    }

    modifier whenMultistrategyBalanceLowerThanWithdrawAmount() {
        strategy_one = deployMockStrategyAdapter(address(multistrategy), IERC4626(address(multistrategy)).asset());
        strategy_two = deployMockStrategyAdapter(address(multistrategy), IERC4626(address(multistrategy)).asset());
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
        IStrategyAdapterMock(strategy_two).setStakingSlippage(5_000);

        amountToWithdraw = 1000 ether;
        swapCaller(users.bob);

        // Expect a revert
        vm.expectRevert(abi.encodeWithSelector(Errors.SlippageCheckFailed.selector, 200 ether, 100 ether));
        IERC4626(address(multistrategy)).withdraw(amountToWithdraw, users.bob, users.bob);
    }

    /// @dev To revert when the withdraw needs more shares to cover thw withdraw than initially thought
    function test_RevertWhen_SharesSlippage()
        external
        whenContractNotPaused
        whenHasCallerEnoughSharesToCoverWithdraw
        whenAmountGreaterThanZero
        whenMultistrategyBalanceLowerThanWithdrawAmount
    {   
        IStrategyAdapterMock(strategy_one).setSlippageLimit(200);
        IStrategyAdapterMock(strategy_one).setStakingSlippage(100);

        amountToWithdraw = 800 ether;
        swapCaller(users.bob);

        // Expect a revert
        vm.expectRevert(abi.encodeWithSelector(Errors.SlippageCheckFailed.selector, 800 ether, 804020100502512562815));
        IERC4626(address(multistrategy)).withdraw(amountToWithdraw, users.bob, users.bob);
    }


    modifier whenWithdrawOrderEndReached() {
        _;
    }

    modifier whenNotEnoughBalanceToCoverWithdraw() {
        // Remove slippage protection
        IStrategyAdapterMock(strategy_two).setSlippageLimit(10_000);
        // Set the staking slippage to 50%. If a user wants to withdraw 1000 tokens, the staking
        // will only return 500 tokens
        IStrategyAdapterMock(strategy_two).setStakingSlippage(5_000);
        _;
    }

    /// @dev Test case where it reaches the end of the withdraw queue but it doesn't
    /// have enough funds to cover the withdraw.
    function test_RevertWhen_QueueEndNoBalanceToCoverWithdraw() 
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

        vm.expectRevert(abi.encodeWithSelector(Errors.InsufficientLiquidity.selector, amountToWithdraw, 900 ether));
        IERC4626(address(multistrategy)).withdraw(amountToWithdraw, users.bob, users.bob);
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
        IERC4626(address(multistrategy)).withdraw(amountToWithdraw, users.bob, users.bob);

        // Assert the user balance
        uint256 actualUserBalance = asset.balanceOf(users.bob);
        uint256 expectedUserBalance = amountToWithdraw;
        assertEq(actualUserBalance, expectedUserBalance, "withdraw, user balance");

        // Assert the user shares balance
        uint256 actualUserSharesBalance = IERC20(address(multistrategy)).balanceOf(users.bob);
        uint256 expectedUserSharesBalance = depositAmount - amountToWithdraw;
        assertEq(actualUserSharesBalance, expectedUserSharesBalance, "withdraw, user shares balance");

        // Assert multistrategy reserves.
        uint256 actualMultistrategyBalance = asset.balanceOf(address(multistrategy));
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

        // Assert multistrategy totalDebt
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
        IERC4626(address(multistrategy)).withdraw(amountToWithdraw, users.bob, users.bob);

        // Assert the user balance
        uint256 actualUserBalance = asset.balanceOf(users.bob);
        uint256 expectedUserBalance = amountToWithdraw;
        assertEq(actualUserBalance, expectedUserBalance, "withdraw, user balance");

        // Assert the user shares balance
        uint256 actualUserSharesBalance = IERC20(address(multistrategy)).balanceOf(users.bob);
        uint256 expectedUserSharesBalance = depositAmount - amountToWithdraw;
        assertEq(actualUserSharesBalance, expectedUserSharesBalance, "withdraw, user shares balance");

        // Assert multistrategy reserves.
        uint256 actualMultistrategyBalance = asset.balanceOf(address(multistrategy));
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

        // Assert multistrategy totalDebt
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
        strategy_one = deployMockStrategyAdapter(address(multistrategy), IERC4626(address(multistrategy)).asset());
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
        IERC4626(address(multistrategy)).withdraw(amountToWithdraw, users.bob, users.bob);

        // Assert the user balance
        uint256 actualUserBalance = asset.balanceOf(users.bob);
        uint256 expectedUserBalance = amountToWithdraw;
        assertEq(actualUserBalance, expectedUserBalance, "withdraw, user balance");

        // Assert the user shares balance
        uint256 actualUserSharesBalance = IERC20(address(multistrategy)).balanceOf(users.bob);
        uint256 expectedUserSharesBalance = depositAmount - amountToWithdraw;
        assertEq(actualUserSharesBalance, expectedUserSharesBalance, "withdraw, user shares balance");

        // Assert multistrategy reserves
        uint256 actualMultistrategyBalance = asset.balanceOf(address(multistrategy));
        uint256 expectedMultistrategyBalance = 0;
        assertEq(actualMultistrategyBalance, expectedMultistrategyBalance, "withdraw, multistrategy balance");

        // Assert strategy_one assets
        uint256 actualStrategyOneAssets = IStrategyAdapter(strategy_one).totalAssets();
        uint256 expectedStrategyOneAssets = 500 ether;
        assertEq(actualStrategyOneAssets, expectedStrategyOneAssets, "withdraw, strategy one assets");

        // Assert multistrategy totalDebt
        uint256 actualMultistrategyDebt = multistrategy.totalDebt();
        uint256 expectedMultistrategyDebt = depositAmount - amountToWithdraw;
        assertEq(actualMultistrategyDebt, expectedMultistrategyDebt, "withdraw, multistrategy total debt");

        // Assert strategy_one totalDebt
        uint256 actualStrategyOneDebt = multistrategy.getStrategyParameters(strategy_one).totalDebt;
        uint256 expectedStrategyOneDebt = 500 ether;
        assertEq(actualStrategyOneDebt, expectedStrategyOneDebt, "withdraw, strategy one debt");
    }
}