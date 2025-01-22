// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.20 <0.9.0;

import { IERC4626, Multistrategy_Integration_Shared_Test } from "../../../shared/Multistrategy.t.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import { IStrategyAdapter } from "interfaces/infra/multistrategy/IStrategyAdapter.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { Errors } from "src/infra/libraries/Errors.sol";

interface IStrategyAdapterMock {
    function earn(uint256 _amount) external;
    function lose(uint256 _amount) external;
    function withdrawFromStaking(uint256 _amount) external;
}

contract StrategyReport_Integration_Concrete_Test is Multistrategy_Integration_Shared_Test {
    address strategy;
    uint256 deposit = 1_000;
    uint256 gainAmount;
    uint256 loseAmount;
    uint256 repayAmount;

    uint8 decimals;

    function setUp() public virtual override {
        Multistrategy_Integration_Shared_Test.setUp();
        decimals = IERC20Metadata(IERC4626(address(multistrategy)).asset()).decimals();
    }
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

    function test_RevertWhen_CallerNotActiveStrategy()
        external
        whenContractNotPaused    
    {   
        // Expect a revert
        vm.expectRevert(abi.encodeWithSelector(Errors.StrategyNotActive.selector, users.owner));
        multistrategy.requestCredit();
    }

    modifier whenCallerActiveStrategy() {
        strategy = deployMockStrategyAdapter(address(multistrategy), IERC4626(address(multistrategy)).asset());
        multistrategy.addStrategy(strategy, 5_000, 0, 100_000 * 10 ** decimals);

        triggerUserDeposit(users.bob, 1_000 * 10 ** decimals);
        _;
    }

    function test_RevertWhen_StrategyReportsGainAndLoss()
        external
        whenContractNotPaused
        whenCallerActiveStrategy
    {
        repayAmount = 0;
        gainAmount = 100 * 10 ** decimals;
        loseAmount = 100 * 10 ** decimals;

        swapCaller(strategy);

        // Expect a revert
        vm.expectRevert(abi.encodeWithSelector(Errors.GainLossMismatch.selector));
        multistrategy.strategyReport(repayAmount, gainAmount, loseAmount);
    }

    modifier whenStrategyOnlyReportsGainOrLoss() {
        _;
    }

    function test_RevertWhen_StrategyLacksBalanceToRepayDebt()
        external
        whenContractNotPaused
        whenCallerActiveStrategy
        whenStrategyOnlyReportsGainOrLoss
    {
        repayAmount = 0;
        gainAmount = 100 * 10 ** decimals;
        loseAmount = 0;

        swapCaller(strategy);

        // Expect a revert
        vm.expectRevert(abi.encodeWithSelector(Errors.InsufficientBalance.selector, 0, repayAmount + gainAmount));
        multistrategy.strategyReport(repayAmount, gainAmount, loseAmount);
    }

    modifier whenStrategyHasBalanceToRepay(uint256 _amount) {
        swapCaller(users.owner);
        IStrategyAdapter(strategy).requestCredit();

        IStrategyAdapterMock(strategy).withdrawFromStaking(_amount);
        _;
    }

    modifier whenStrategyHasMadeALoss(uint256 _amount) {
        IStrategyAdapterMock(strategy).lose(_amount);
        _;
    }

    modifier whenStrategyHasExceedingDebt() {
        swapCaller(users.owner);
        multistrategy.setStrategyDebtRatio(strategy,  0);
        _;
    }

    /// @dev LockedProfit is 0 here as the strategy still hasn't reported any gain. So any loss
    /// will be higher than the locked profit.
    function test_StrategyReport_LossHigherThanLockedProfit_ExceedingDebt()
        external
        whenContractNotPaused
        whenCallerActiveStrategy
        whenStrategyOnlyReportsGainOrLoss
        whenStrategyHasBalanceToRepay(100 * 10 ** decimals)
        whenStrategyHasMadeALoss(100 * 10 ** decimals)
        whenStrategyHasExceedingDebt
    {   
        repayAmount = 100 * 10 ** decimals;
        gainAmount = 0;
        loseAmount = 100 * 10 ** decimals;

        swapCaller(strategy);
        vm.expectEmit({emitter: address(multistrategy)});
        emit StrategyReported(strategy, repayAmount, gainAmount, loseAmount);

        // Report with [100, 0, 100]
        multistrategy.strategyReport(repayAmount, gainAmount, loseAmount);

        // Assert that the loss has been reported
        uint256 actualMultistrategyTotalAssets = IERC4626(address(multistrategy)).totalAssets();
        uint256 expectedMultistrategyTotalAssets = (deposit * 10 ** decimals) - loseAmount;
        assertEq(actualMultistrategyTotalAssets, expectedMultistrategyTotalAssets, "strategyReport multistrategy totalAssets");

        // Assert that the strategy paid the debt with the balance it made available
        uint256 actualMultistrategyBalance = asset.balanceOf(address(multistrategy));
        uint256 expectedMultistrategyBalance = (500 * 10 ** decimals) + repayAmount;
        assertEq(actualMultistrategyBalance, expectedMultistrategyBalance, "strategyReport multistrategy balance");

        // Assert that the strategy total assets have been reduced by the repayment and lose amount
        uint256 actualStrategyTotalAssets = IStrategyAdapter(strategy).totalAssets();
        uint256 expectedStrategyTotalAssets = (500 * 10 ** decimals) - repayAmount - loseAmount;
        assertEq(actualStrategyTotalAssets, expectedStrategyTotalAssets, "strategyReport strategy totalAssets");

        // Assert that locked profit is zero
        uint256 actualLockedProfit = multistrategy.lockedProfit();
        uint256 expectedLockedProfit = 0;
        assertEq(actualLockedProfit, expectedLockedProfit, "strategyReport lockedProfit");

        // Assert that the multistrategy las report has been updated
        uint256 actualMultistrategyLastReport = multistrategy.lastReport();
        uint256 expectedMultistrategyLastReport = block.timestamp;
        assertEq(actualMultistrategyLastReport, expectedMultistrategyLastReport, "strategyReport multistrategy lastReport");

        // Assert that the multistrategy las report has been updated
        uint256 actualStrategyLastReport = multistrategy.getStrategyParameters(strategy).lastReport;
        uint256 expectedStrategyLastReport = block.timestamp;
        assertEq(actualStrategyLastReport, expectedStrategyLastReport, "strategyReport strategy lastReport");
    }

    function test_StrategyReport_LossHigherThanLockedProfit_NoExceedingDebt()
        external
        whenContractNotPaused
        whenCallerActiveStrategy
        whenStrategyOnlyReportsGainOrLoss
        whenStrategyHasBalanceToRepay(0)
        whenStrategyHasMadeALoss(100  * 10 ** decimals)
    {
        repayAmount = 0;
        gainAmount = 0;
        loseAmount = 100  * 10 ** decimals;

        swapCaller(strategy);
        vm.expectEmit({emitter: address(multistrategy)});
        emit StrategyReported(strategy, repayAmount, gainAmount, loseAmount);

        // Report with [0, 0, 100]
        multistrategy.strategyReport(repayAmount, gainAmount, loseAmount);

        // Assert that the loss has been reported
        uint256 actualMultistrategyTotalAssets = IERC4626(address(multistrategy)).totalAssets();
        uint256 expectedMultistrategyTotalAssets = (deposit  * 10 ** decimals) - loseAmount;
        assertEq(actualMultistrategyTotalAssets, expectedMultistrategyTotalAssets, "strategyReport multistrategy totalAssets");

        // Assert that the strategy didn't pay any debt
        uint256 actualMultistrategyBalance = asset.balanceOf(address(multistrategy));
        uint256 expectedMultistrategyBalance = 500  * 10 ** decimals;
        assertEq(actualMultistrategyBalance, expectedMultistrategyBalance, "strategyReport multistrategy balance");

        // Assert that the strategy total assets have been reduced by the lose amount
        uint256 actualStrategyTotalAssets = IStrategyAdapter(strategy).totalAssets();
        uint256 expectedStrategyTotalAssets = (500  * 10 ** decimals) - loseAmount;
        assertEq(actualStrategyTotalAssets, expectedStrategyTotalAssets, "strategyReport strategy totalAssets");

        // Assert that locked profit is zero
        uint256 actualLockedProfit = multistrategy.lockedProfit();
        uint256 expectedLockedProfit = 0;
        assertEq(actualLockedProfit, expectedLockedProfit, "strategyReport lockedProfit");

        // Assert that the multistrategy las report has been updated
        uint256 actualMultistrategyLastReport = multistrategy.lastReport();
        uint256 expectedMultistrategyLastReport = block.timestamp;
        assertEq(actualMultistrategyLastReport, expectedMultistrategyLastReport, "strategyReport multistrategy lastReport");

        // Assert that the multistrategy las report has been updated
        uint256 actualStrategyLastReport = multistrategy.getStrategyParameters(strategy).lastReport;
        uint256 expectedStrategyLastReport = block.timestamp;
        assertEq(actualStrategyLastReport, expectedStrategyLastReport, "strategyReport strategy lastReport");
    }

    modifier whenThereIsLockedProfit(uint256 _amount) {
        // Report a 100 token gain in order to get some profit locked
        swapCaller(strategy);
        mintAsset(strategy, _amount);
        multistrategy.strategyReport(0, _amount, 0);
        _;
    }

    function test_StrategyReport_LossLowerThanLockedProfit_ExceedingDebt()
        external
        whenContractNotPaused
        whenCallerActiveStrategy
        whenStrategyOnlyReportsGainOrLoss
        whenStrategyHasBalanceToRepay(100  * 10 ** decimals)
        whenStrategyHasMadeALoss(10  * 10 ** decimals)
        whenThereIsLockedProfit(100  * 10 ** decimals)
        whenStrategyHasExceedingDebt
    {   
        repayAmount = 100  * 10 ** decimals;
        gainAmount = 0;
        loseAmount = 10  * 10 ** decimals;
        uint256 profit = 95  * 10 ** decimals;

        swapCaller(strategy);
        vm.expectEmit({emitter: address(multistrategy)});
        emit StrategyReported(strategy, repayAmount, gainAmount, loseAmount);

        // Report with [100, 0, 10]
        multistrategy.strategyReport(repayAmount, gainAmount, loseAmount);

        // Assert that the loss has been reported
        uint256 actualMultistrategyTotalAssets = IERC4626(address(multistrategy)).totalAssets();
        uint256 expectedMultistrategyTotalAssets = (deposit * 10 ** decimals) + profit - loseAmount;
        assertEq(actualMultistrategyTotalAssets, expectedMultistrategyTotalAssets, "strategyReport multistrategy totalAssets");

        // Assert that the strategy paid the debt with the balance it made available
        uint256 actualMultistrategyBalance = asset.balanceOf(address(multistrategy));
        uint256 expectedMultistrategyBalance = (500 * 10 ** decimals) + profit + repayAmount;
        assertEq(actualMultistrategyBalance, expectedMultistrategyBalance, "strategyReport multistrategy balance");

        // Assert that the strategy total assets have been reduced by the repayment and lose amount
        uint256 actualStrategyTotalAssets = IStrategyAdapter(strategy).totalAssets();
        uint256 expectedStrategyTotalAssets = (500 * 10 ** decimals) - repayAmount - loseAmount;
        assertEq(actualStrategyTotalAssets, expectedStrategyTotalAssets, "strategyReport strategy totalAssets");

        // Assert that locked profit is the profit minus the loss
        uint256 actualLockedProfit = multistrategy.lockedProfit();
        uint256 expectedLockedProfit = profit - loseAmount;
        assertEq(actualLockedProfit, expectedLockedProfit, "strategyReport lockedProfit");

        // Assert that the multistrategy las report has been updated
        uint256 actualMultistrategyLastReport = multistrategy.lastReport();
        uint256 expectedMultistrategyLastReport = block.timestamp;
        assertEq(actualMultistrategyLastReport, expectedMultistrategyLastReport, "strategyReport multistrategy lastReport");

        // Assert that the multistrategy las report has been updated
        uint256 actualStrategyLastReport = multistrategy.getStrategyParameters(strategy).lastReport;
        uint256 expectedStrategyLastReport = block.timestamp;
        assertEq(actualStrategyLastReport, expectedStrategyLastReport, "strategyReport strategy lastReport");
    }

    function test_StrategyReport_LossLowerThanLockedProfit_NoExceedingDebt()
        external
        whenContractNotPaused
        whenCallerActiveStrategy
        whenStrategyOnlyReportsGainOrLoss
        whenStrategyHasBalanceToRepay(0)
        whenStrategyHasMadeALoss(10 * 10 ** decimals)
        whenThereIsLockedProfit(100 * 10 ** decimals)
    {
        repayAmount = 0;
        gainAmount = 0;
        loseAmount = 10 * 10 ** decimals;
        uint256 profit = 95 * 10 ** decimals;

        swapCaller(strategy);
        vm.expectEmit({emitter: address(multistrategy)});
        emit StrategyReported(strategy, repayAmount, gainAmount, loseAmount);

        // Report with [100, 0, 10]
        multistrategy.strategyReport(repayAmount, gainAmount, loseAmount);

        // Assert that the loss has been reported
        uint256 actualMultistrategyTotalAssets = IERC4626(address(multistrategy)).totalAssets();
        uint256 expectedMultistrategyTotalAssets = (deposit * 10 ** decimals) + profit - loseAmount;
        assertEq(actualMultistrategyTotalAssets, expectedMultistrategyTotalAssets, "strategyReport multistrategy totalAssets");

        // Assert that the strategy paid the debt with the balance it made available
        uint256 actualMultistrategyBalance = asset.balanceOf(address(multistrategy));
        uint256 expectedMultistrategyBalance = (500 * 10 ** decimals) + profit;
        assertEq(actualMultistrategyBalance, expectedMultistrategyBalance, "strategyReport multistrategy balance");

        // Assert that the strategy total assets have been reduced by the repayment and lose amount
        uint256 actualStrategyTotalAssets = IStrategyAdapter(strategy).totalAssets();
        uint256 expectedStrategyTotalAssets = (500 * 10 ** decimals) - loseAmount;
        assertEq(actualStrategyTotalAssets, expectedStrategyTotalAssets, "strategyReport strategy totalAssets");

        // Assert that locked profit is the profit minus the loss
        uint256 actualLockedProfit = multistrategy.lockedProfit();
        uint256 expectedLockedProfit = profit - loseAmount;
        assertEq(actualLockedProfit, expectedLockedProfit, "strategyReport lockedProfit");

        // Assert that the multistrategy las report has been updated
        uint256 actualMultistrategyLastReport = multistrategy.lastReport();
        uint256 expectedMultistrategyLastReport = block.timestamp;
        assertEq(actualMultistrategyLastReport, expectedMultistrategyLastReport, "strategyReport multistrategy lastReport");

        // Assert that the multistrategy las report has been updated
        uint256 actualStrategyLastReport = multistrategy.getStrategyParameters(strategy).lastReport;
        uint256 expectedStrategyLastReport = block.timestamp;
        assertEq(actualStrategyLastReport, expectedStrategyLastReport, "strategyReport strategy lastReport");
    }

    modifier whenStrategyHasMadeAGain(uint256 _amount) {
        IStrategyAdapterMock(strategy).earn(_amount);
        IStrategyAdapterMock(strategy).withdrawFromStaking(_amount);
        _;
    }

    function test_StrategyReport_Gain_ExceedingDebt()
        external
        whenContractNotPaused
        whenCallerActiveStrategy
        whenStrategyOnlyReportsGainOrLoss
        whenStrategyHasBalanceToRepay(100 * 10 ** decimals)
        whenStrategyHasMadeAGain(100 * 10 ** decimals)
        whenStrategyHasExceedingDebt
    {
        repayAmount = 100 * 10 ** decimals;
        gainAmount = 100 * 10 ** decimals;
        uint256 fee = Math.mulDiv(gainAmount, multistrategy.performanceFee(), 10_000);

        swapCaller(strategy);
        vm.expectEmit({emitter: address(multistrategy)});
        emit StrategyReported(strategy, repayAmount, gainAmount - fee, loseAmount);

        // Report with [100, 100, 0]
        multistrategy.strategyReport(repayAmount, gainAmount, loseAmount);

        uint256 actualFeeRecipientBalance = asset.balanceOf(multistrategy.protocolFeeRecipient());
        uint256 expectedFeeRecipientBalance = fee;
        assertEq(actualFeeRecipientBalance, expectedFeeRecipientBalance, "strategyReport, fee recipient balance");

        // Assert that the gain has been reported
        uint256 actualMultistrategyTotalAssets = IERC4626(address(multistrategy)).totalAssets();
        uint256 expectedMultistrategyTotalAssets = deposit * 10 ** decimals + gainAmount - fee;
        assertEq(actualMultistrategyTotalAssets, expectedMultistrategyTotalAssets, "strategyReport multistrategy totalAssets");

        // Assert that the strategy paid the debt with the balance it made available
        uint256 actualMultistrategyBalance = asset.balanceOf(address(multistrategy));
        uint256 expectedMultistrategyBalance = 500 * 10 ** decimals + repayAmount + gainAmount - fee;
        assertEq(actualMultistrategyBalance, expectedMultistrategyBalance, "strategyReport multistrategy balance");

        // Assert that the strategy total assets have been reduced by the repayment
        uint256 actualStrategyTotalAssets = IStrategyAdapter(strategy).totalAssets();
        uint256 expectedStrategyTotalAssets = 500 * 10 ** decimals - repayAmount;
        assertEq(actualStrategyTotalAssets, expectedStrategyTotalAssets, "strategyReport strategy totalAssets");

        // Assert that locked profit is the profit minus the loss
        uint256 actualLockedProfit = multistrategy.lockedProfit();
        uint256 expectedLockedProfit = gainAmount - fee;
        assertEq(actualLockedProfit, expectedLockedProfit, "strategyReport lockedProfit");

        // Assert that the multistrategy las report has been updated
        uint256 actualMultistrategyLastReport = multistrategy.lastReport();
        uint256 expectedMultistrategyLastReport = block.timestamp;
        assertEq(actualMultistrategyLastReport, expectedMultistrategyLastReport, "strategyReport multistrategy lastReport");

        // Assert that the multistrategy las report has been updated
        uint256 actualStrategyLastReport = multistrategy.getStrategyParameters(strategy).lastReport;
        uint256 expectedStrategyLastReport = block.timestamp;
        assertEq(actualStrategyLastReport, expectedStrategyLastReport, "strategyReport strategy lastReport");
    }

    function test_StrategyReport_Gain_NoExceedingDebt()
        external
        whenContractNotPaused
        whenCallerActiveStrategy
        whenStrategyOnlyReportsGainOrLoss
        whenStrategyHasBalanceToRepay(0)
        whenStrategyHasMadeAGain(100 * 10 ** decimals)
    {
        repayAmount = 0;
        gainAmount = 100 * 10 ** decimals;
        uint256 fee = Math.mulDiv(gainAmount, multistrategy.performanceFee(), 10_000);

        swapCaller(strategy);
        vm.expectEmit({emitter: address(multistrategy)});
        emit StrategyReported(strategy, repayAmount, gainAmount - fee, loseAmount);

        // Report with [100, 100, 0]
        multistrategy.strategyReport(repayAmount, gainAmount, loseAmount);

        uint256 actualFeeRecipientBalance = asset.balanceOf(multistrategy.protocolFeeRecipient());
        uint256 expectedFeeRecipientBalance = fee;
        assertEq(actualFeeRecipientBalance, expectedFeeRecipientBalance, "strategyReport, fee recipient balance");

        // Assert that the gain has been reported
        uint256 actualMultistrategyTotalAssets = IERC4626(address(multistrategy)).totalAssets();
        uint256 expectedMultistrategyTotalAssets = deposit * 10 ** decimals + gainAmount - fee;
        assertEq(actualMultistrategyTotalAssets, expectedMultistrategyTotalAssets, "strategyReport multistrategy totalAssets");

        // Assert that the strategy paid the debt with the balance it made available
        uint256 actualMultistrategyBalance = asset.balanceOf(address(multistrategy));
        uint256 expectedMultistrategyBalance = 500 * 10 ** decimals + gainAmount - fee;
        assertEq(actualMultistrategyBalance, expectedMultistrategyBalance, "strategyReport multistrategy balance");

        // Assert that the strategy total assets have been reduced by the repayment
        uint256 actualStrategyTotalAssets = IStrategyAdapter(strategy).totalAssets();
        uint256 expectedStrategyTotalAssets = 500 * 10 ** decimals;
        assertEq(actualStrategyTotalAssets, expectedStrategyTotalAssets, "strategyReport strategy totalAssets");

        // Assert that the multistrategy las report has been updated
        uint256 actualMultistrategyLastReport = multistrategy.lastReport();
        uint256 expectedMultistrategyLastReport = block.timestamp;
        assertEq(actualMultistrategyLastReport, expectedMultistrategyLastReport, "strategyReport multistrategy lastReport");

        // Assert that the multistrategy las report has been updated
        uint256 actualStrategyLastReport = multistrategy.getStrategyParameters(strategy).lastReport;
        uint256 expectedStrategyLastReport = block.timestamp;
        assertEq(actualStrategyLastReport, expectedStrategyLastReport, "strategyReport strategy lastReport");
    }
}