// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.20 <0.9.0;

import { IERC4626, Multistrategy_Integration_Shared_Test } from "../../../shared/Multistrategy.t.sol";
import { IStrategyAdapter } from "interfaces/infra/multistrategy/IStrategyAdapter.sol";
import { IStrategyAdapterMock } from "../../../../shared/TestInterfaces.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";
import { Errors } from "src/infra/libraries/Errors.sol";

contract Redeem_Integration_Concrete_Test is Multistrategy_Integration_Shared_Test {
    uint256 depositAmount = 1000 ether;
    uint256 amountToRedeem;

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

    function test_RevertWhen_CallerNotEnoughSharesToCoverRedeem() external {
        amountToRedeem = 1000 ether;

        // Expect a revert
        vm.expectRevert(abi.encodeWithSelector(Errors.ERC4626ExceededMaxRedeem.selector, users.bob, amountToRedeem, 0));
        IERC4626(address(multistrategy)).redeem(amountToRedeem, users.bob, users.bob);
    }

    modifier whenHasCallerEnoughSharesToCoverRedeem() {
        triggerUserDeposit(users.bob, depositAmount);
        _;
    }

    function test_RevertWhen_AmountIsZero()
        external
        whenHasCallerEnoughSharesToCoverRedeem
    {
        amountToRedeem = 0;

        // Expect a revert
        vm.expectRevert(abi.encodeWithSelector(Errors.ZeroAmount.selector, amountToRedeem));
        IERC4626(address(multistrategy)).redeem(amountToRedeem, users.bob, users.bob);
    }

    modifier whenAmountGreaterThanZero() {
        _;
    }

    modifier whenMultistrategyBalanceLowerThanRedeemAmount() {
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
        whenHasCallerEnoughSharesToCoverRedeem
        whenAmountGreaterThanZero
        whenMultistrategyBalanceLowerThanRedeemAmount
    {
        IStrategyAdapterMock(strategy_two).setStakingSlippage(5_000);

        amountToRedeem = 1000 ether;
        swapCaller(users.bob);

        // Expect a revert
        vm.expectRevert(abi.encodeWithSelector(Errors.SlippageCheckFailed.selector, 200 ether, 100 ether));
        IERC4626(address(multistrategy)).redeem(amountToRedeem, users.bob, users.bob);
    }

    /// @dev To revert when the redeem returns less assets than initially thought
    function test_RevertWhen_AssetsSlippage()
        external
        whenContractNotPaused
        whenHasCallerEnoughSharesToCoverRedeem
        whenAmountGreaterThanZero
        whenMultistrategyBalanceLowerThanRedeemAmount
    {   
        IStrategyAdapterMock(strategy_one).setSlippageLimit(200);
        IStrategyAdapterMock(strategy_one).setStakingSlippage(100);

        amountToRedeem = 800 ether;
        swapCaller(users.bob);

        // Expect a revert
        vm.expectRevert(abi.encodeWithSelector(Errors.SlippageCheckFailed.selector, 800 ether, 796 ether));
        IERC4626(address(multistrategy)).redeem(amountToRedeem, users.bob, users.bob);
    }

    modifier whenWithdrawOrderEndReached() {
        _;
    }

    /// @dev Test case where it reaches the end of the withdraw queue and it has enough
    /// funds to cover the redeem
    function test_Redeem_QueueEnd() 
        external
        whenContractNotPaused
        whenHasCallerEnoughSharesToCoverRedeem
        whenAmountGreaterThanZero
        whenMultistrategyBalanceLowerThanRedeemAmount
        whenWithdrawOrderEndReached
    {
        amountToRedeem = 1000 ether;

        swapCaller(users.bob);
        IERC4626(address(multistrategy)).redeem(amountToRedeem, users.bob, users.bob);

        // Assert the user balance
        uint256 actualUserBalance = asset.balanceOf(users.bob);
        uint256 expectedUserBalance = amountToRedeem;
        assertEq(actualUserBalance, expectedUserBalance, "redeem, user balance");

        // Assert the user shares balance
        uint256 actualUserSharesBalance = IERC20(address(multistrategy)).balanceOf(users.bob);
        uint256 expectedUserSharesBalance = depositAmount - amountToRedeem;
        assertEq(actualUserSharesBalance, expectedUserSharesBalance, "redeem, user shares balance");

        // Assert multistrategy reserves.
        uint256 actualMultistrategyBalance = asset.balanceOf(address(multistrategy));
        uint256 expectedMultistrategyBalance = 0;
        assertEq(actualMultistrategyBalance, expectedMultistrategyBalance, "redeem, multistrategy balance");

        // Assert strategy_one assets.
        uint256 actualStrategyOneAssets = IStrategyAdapter(strategy_one).totalAssets();
        uint256 expectedStrategyOneAssets = 0;
        assertEq(actualStrategyOneAssets, expectedStrategyOneAssets, "redeem, strategy one assets");

        // Assert strategy_two assets.
        uint256 actualStrategyTwoAssets = IStrategyAdapter(strategy_two).totalAssets();
        uint256 expectedStrategyTwoAssets = 0;
        assertEq(actualStrategyTwoAssets, expectedStrategyTwoAssets, "redeem, strategy two assets");

        // Assert multistrategy totalDebt
        uint256 actualMultistrategyDebt = multistrategy.totalDebt();
        uint256 expectedMultistrategyDebt = depositAmount - amountToRedeem;
        assertEq(actualMultistrategyDebt, expectedMultistrategyDebt, "redeem, multistrategy total debt");

        // Assert strategy_one totalDebt
        uint256 actualStrategyOneDebt = multistrategy.getStrategyParameters(strategy_one).totalDebt;
        uint256 expectedStrategyOneDebt = 0;
        assertEq(actualStrategyOneDebt, expectedStrategyOneDebt, "redeem, strategy one debt");

        // Assert strategy_two totalDebt
        uint256 actualStrategyTwoDebt = multistrategy.getStrategyParameters(strategy_two).totalDebt;
        uint256 expectedStrategyTwoDebt = 0 ether;
        assertEq(actualStrategyTwoDebt, expectedStrategyTwoDebt, "redeem, strategy two debt");
    }

    /// @dev Test case where the withdraw process is started and it gets
    // enough funds to cover the redeem without reaching the queue end
    function test_Redeem_NotReachQueueEnd()
        external
        whenContractNotPaused
        whenHasCallerEnoughSharesToCoverRedeem
        whenAmountGreaterThanZero
        whenMultistrategyBalanceLowerThanRedeemAmount
    {
        amountToRedeem = 800 ether;

        swapCaller(users.bob);
        IERC4626(address(multistrategy)).redeem(amountToRedeem, users.bob, users.bob);

        // Assert the user balance
        uint256 actualUserBalance = asset.balanceOf(users.bob);
        uint256 expectedUserBalance = amountToRedeem;
        assertEq(actualUserBalance, expectedUserBalance, "redeem, user balance");

        // Assert the user shares balance
        uint256 actualUserSharesBalance = IERC20(address(multistrategy)).balanceOf(users.bob);
        uint256 expectedUserSharesBalance = depositAmount - amountToRedeem;
        assertEq(actualUserSharesBalance, expectedUserSharesBalance, "redeem, user shares balance");

        // Assert multistrategy reserves.
        uint256 actualMultistrategyBalance = asset.balanceOf(address(multistrategy));
        uint256 expectedMultistrategyBalance = 0;
        assertEq(actualMultistrategyBalance, expectedMultistrategyBalance, "redeem, multistrategy balance");

        // Assert strategy_one assets
        uint256 actualStrategyOneAssets = IStrategyAdapter(strategy_one).totalAssets();
        uint256 expectedStrategyOneAssets = 0;
        assertEq(actualStrategyOneAssets, expectedStrategyOneAssets, "redeem, strategy one assets");

        // Assert strategy_two assets
        uint256 actualStrategyTwoAssets = IStrategyAdapter(strategy_two).totalAssets();
        uint256 expectedStrategyTwoAssets = 200 ether;
        assertEq(actualStrategyTwoAssets, expectedStrategyTwoAssets, "redeem, strategy two assets");

        // Assert multistrategy totalDebt
        uint256 actualMultistrategyDebt = multistrategy.totalDebt();
        uint256 expectedMultistrategyDebt = depositAmount - amountToRedeem;
        assertEq(actualMultistrategyDebt, expectedMultistrategyDebt, "redeem, multistrategy total debt");

        // Assert strategy_one totalDebt
        uint256 actualStrategyOneDebt = multistrategy.getStrategyParameters(strategy_one).totalDebt;
        uint256 expectedStrategyOneDebt = 0;
        assertEq(actualStrategyOneDebt, expectedStrategyOneDebt, "redeem, strategy one debt");

        // Assert strategy_two totalDebt
        uint256 actualStrategyTwoDebt = multistrategy.getStrategyParameters(strategy_two).totalDebt;
        uint256 expectedStrategyTwoDebt = 200 ether;
        assertEq(actualStrategyTwoDebt, expectedStrategyTwoDebt, "redeem, strategy two debt");
    }

    modifier whenMultistrategyBalanceHigherOrEqualThanRedeemAmount() {
        strategy_one = deployMockStrategyAdapter(address(multistrategy), IERC4626(address(multistrategy)).asset());
        multistrategy.addStrategy(strategy_one, 5_000, 0, 100_000 ether);

        IStrategyAdapter(strategy_one).requestCredit();
        _;
    }

    /// @dev Test case where redeem can be covered by the reserves in the multistrategy contract
    function test_Redeem_NoWithdrawProcess() 
        external
        whenContractNotPaused
        whenHasCallerEnoughSharesToCoverRedeem
        whenAmountGreaterThanZero
        whenMultistrategyBalanceHigherOrEqualThanRedeemAmount
    {
        amountToRedeem = 500 ether;

        swapCaller(users.bob);
        IERC4626(address(multistrategy)).redeem(amountToRedeem, users.bob, users.bob);

        // Assert the user balance
        uint256 actualUserBalance = asset.balanceOf(users.bob);
        uint256 expectedUserBalance = amountToRedeem;
        assertEq(actualUserBalance, expectedUserBalance, "redeem, user balance");

        // Assert the user shares balance
        uint256 actualUserSharesBalance = IERC20(address(multistrategy)).balanceOf(users.bob);
        uint256 expectedUserSharesBalance = depositAmount - amountToRedeem;
        assertEq(actualUserSharesBalance, expectedUserSharesBalance, "redeem, user shares balance");

        // Assert multistrategy reserves
        uint256 actualMultistrategyBalance = asset.balanceOf(address(multistrategy));
        uint256 expectedMultistrategyBalance = 0;
        assertEq(actualMultistrategyBalance, expectedMultistrategyBalance, "redeem, multistrategy balance");

        // Assert strategy_one assets
        uint256 actualStrategyOneAssets = IStrategyAdapter(strategy_one).totalAssets();
        uint256 expectedStrategyOneAssets = 500 ether;
        assertEq(actualStrategyOneAssets, expectedStrategyOneAssets, "redeem, strategy one assets");

        // Assert multistrategy totalDebt
        uint256 actualMultistrategyDebt = multistrategy.totalDebt();
        uint256 expectedMultistrategyDebt = depositAmount - amountToRedeem;
        assertEq(actualMultistrategyDebt, expectedMultistrategyDebt, "redeem, multistrategy total debt");

        // Assert strategy_one totalDebt
        uint256 actualStrategyOneDebt = multistrategy.getStrategyParameters(strategy_one).totalDebt;
        uint256 expectedStrategyOneDebt = 500 ether;
        assertEq(actualStrategyOneDebt, expectedStrategyOneDebt, "redeem, strategy one debt");
    }
}