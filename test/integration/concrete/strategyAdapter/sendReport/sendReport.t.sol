// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.8.20 <0.9.0;

import { IERC20Errors } from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import { IERC4626, StrategyAdapter_Integration_Shared_Test } from "../../../shared/StrategyAdapter.t.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";
import { Errors } from "src/infra/libraries/Errors.sol";

contract SendReport_Integration_Concrete_Test is StrategyAdapter_Integration_Shared_Test {
    function test_RevertWhen_CallerNotOwner() external {
        // Change caller to bob
        swapCaller(users.bob);

        // Expect it to revert
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, users.bob));
        strategy.requestCredit();
    }

    modifier whenCallerOwner() {
        _;
    }

    function test_RevertWhen_ContractPaused() 
        external
        whenCallerOwner
    {
        strategy.pause();
        
        // Expect it to revert
        vm.expectRevert(abi.encodeWithSelector(Pausable.EnforcedPause.selector));
        strategy.sendReport(0);
    }

    modifier whenContractNotPaused() {
        _;
    }

    function test_RevertWhen_RepayAmountHigherThanTotalAssets()
        external
        whenCallerOwner
        whenContractNotPaused
    {
        // Request a credit from the multistrategy
        requestCredit(strategy, 1_000 * 10 ** decimals);

        // Make a loss
        strategy.lose(100 * 10 ** decimals);

        // Set the strategy debt ratio to 0, se we can repay the debt
        multistrategy.setStrategyDebtRatio(address(strategy), 0);

        uint256 repayAmount = 1000 * 10 ** decimals;

        // Expect a revert when the strategy manager wants to repay all the debt but it doesn't have the assets to do so
        vm.expectRevert();
        strategy.sendReport(repayAmount);
    }

    function test_RevertWhen_SlippageLimitNotRespected()
        external
        whenCallerOwner
        whenContractNotPaused
    {
        // Set the slippage limit of the strategy to 10%
        strategy.setSlippageLimit(1_000);

        // Set the staking slippage to be 15%
        strategy.setStakingSlippage(1_500);

        // Request a credit from the multistrategy
        requestCredit(strategy, 1_000 * 10 ** decimals);

        // Set the strategy debt ratio to 0, se we can repay the debt
        multistrategy.setStrategyDebtRatio(address(strategy), 0);

        // Expect a revert
        vm.expectRevert(abi.encodeWithSelector(Errors.SlippageCheckFailed.selector, 900 * 10 ** decimals, 850 * 10 ** decimals));
        strategy.sendReport(1_000 * 10 ** decimals);
    }

    modifier whenSlippageLimitRespected() {
        // Set the slippage limit of the strategy to 0%
        strategy.setSlippageLimit(0);
        // Set the staking slippage to be 0%
        strategy.setStakingSlippage(0);
        // Request a credit from the multistrategy
        requestCredit(strategy, 1_000 * 10 ** decimals);
        _;
    }

    modifier whenNoDebtRepayment() {
        _;
    }

    modifier whenStrategyMadeGain() {
        // Makes a 100 ether gain (10%)
        strategy.earn(100 * 10 ** decimals);
        _;
    }

    modifier whenStrategyMadeLoss() {
        // Makes a 100 ether loss (-10%)
        strategy.lose(100 * 10 ** decimals);
        _;
    }

    function test_SendReport_ZeroDebtRepayWithGain() 
        external
        whenCallerOwner
        whenContractNotPaused
        whenSlippageLimitRespected
        whenNoDebtRepayment
        whenStrategyMadeGain
    {
        strategy.sendReport(0);

        // Assert it has withdrawn the gain
        uint256 actualStrategyAssets = strategy.totalAssets();
        uint256 expectedStrategyAssets = 1000 * 10 ** decimals;
        assertEq(actualStrategyAssets, expectedStrategyAssets, "withdraw, strategy assets");

        // Assert it has sent the gain to the multistrategy
        uint256 actualMultistrategyAssets = IERC4626(address(multistrategy)).totalAssets();
        uint256 expectedMultistrategyAssets = 1095 * 10 ** decimals;
        assertEq(actualMultistrategyAssets, expectedMultistrategyAssets, "withdraw, multistrategy assets");
    }

    function test_SendReport_ZeroDebtRepayWithLoss()
        external
        whenCallerOwner
        whenContractNotPaused
        whenSlippageLimitRespected
        whenNoDebtRepayment
        whenStrategyMadeLoss
    {
        strategy.sendReport(0);

        // Assert it has withdrawn the gain
        uint256 actualStrategyAssets = strategy.totalAssets();
        uint256 expectedStrategyAssets = 900 * 10 ** decimals;
        assertEq(actualStrategyAssets, expectedStrategyAssets, "withdraw, strategy assets");

        // Assert it has sent the gain to the multistrategy
        uint256 actualMultistrategyAssets = IERC4626(address(multistrategy)).totalAssets();
        uint256 expectedMultistrategyAssets = 900 * 10 ** decimals;
        assertEq(actualMultistrategyAssets, expectedMultistrategyAssets, "withdraw, multistrategy assets");
    }

    modifier whenDebtRepayment() {
        _;
    }

    function test_SendReport_DebtRepayNoExcessDebtWithGain()
        external
        whenCallerOwner
        whenContractNotPaused
        whenSlippageLimitRespected
        whenDebtRepayment
        whenStrategyMadeGain
    {
        strategy.sendReport(1000 * 10 ** decimals);

        // Assert it has withdrawn the gain
        uint256 actualStrategyAssets = strategy.totalAssets();
        uint256 expectedStrategyAssets = 1000 * 10 ** decimals;
        assertEq(actualStrategyAssets, expectedStrategyAssets, "withdraw, strategy assets");

        // Assert it has sent the gain to the multistrategy
        uint256 actualMultistrategyAssets = IERC4626(address(multistrategy)).totalAssets();
        uint256 expectedMultistrategyAssets = 1095 * 10 ** decimals;
        assertEq(actualMultistrategyAssets, expectedMultistrategyAssets, "withdraw, multistrategy assets");
    }

    function test_SendReport_DebtRepayNoExcessDebtWithLoss()
        external
        whenCallerOwner
        whenContractNotPaused
        whenSlippageLimitRespected
        whenDebtRepayment
        whenStrategyMadeLoss
    {
        strategy.sendReport(1000 * 10 ** decimals);

        // Assert it has withdrawn the gain
        uint256 actualStrategyAssets = strategy.totalAssets();
        uint256 expectedStrategyAssets = 900 * 10 ** decimals;
        assertEq(actualStrategyAssets, expectedStrategyAssets, "withdraw, strategy assets");

        // Assert it has sent the gain to the multistrategy
        uint256 actualMultistrategyAssets = IERC4626(address(multistrategy)).totalAssets();
        uint256 expectedMultistrategyAssets = 900 * 10 ** decimals;
        assertEq(actualMultistrategyAssets, expectedMultistrategyAssets, "withdraw, multistrategy assets");
    }

    modifier whenStrartegyHasDebtExcess () {
        // Set the strategy debt ratio to 0, se we can repay the debt
        multistrategy.setStrategyDebtRatio(address(strategy), 0);
        _;
    }


    function test_SendReport_DebtRepayExcessDebtWithGain()
        external
        whenCallerOwner
        whenContractNotPaused
        whenSlippageLimitRespected
        whenDebtRepayment
        whenStrartegyHasDebtExcess
        whenStrategyMadeGain
    {
        strategy.sendReport(1000 * 10 ** decimals);

        // Assert it has withdrawn the gain
        uint256 actualStrategyAssets = strategy.totalAssets();
        uint256 expectedStrategyAssets = 0 * 10 ** decimals;
        assertEq(actualStrategyAssets, expectedStrategyAssets, "withdraw, strategy assets");

        // Assert it has sent the gain to the multistrategy
        uint256 actualMultistrategyAssets = IERC4626(address(multistrategy)).totalAssets();
        uint256 expectedMultistrategyAssets = 1095 * 10 ** decimals;
        assertEq(actualMultistrategyAssets, expectedMultistrategyAssets, "withdraw, multistrategy assets");
    }

    function test_SendReport_DebtRepayExcessDebtWithLoss()
        external
        whenCallerOwner
        whenContractNotPaused
        whenSlippageLimitRespected
        whenDebtRepayment
        whenStrartegyHasDebtExcess
        whenStrategyMadeLoss
    {
        // Note that we're only withdrawing 900 ether. Withdrawing more than totalAssets would revert
        // with InsufficientBalance
        strategy.sendReport(900 * 10 ** decimals);

        // Assert it has withdrawn the gain
        uint256 actualStrategyAssets = strategy.totalAssets();
        uint256 expectedStrategyAssets = 0 * 10 ** decimals;
        assertEq(actualStrategyAssets, expectedStrategyAssets, "withdraw, strategy assets");

        // Assert it has sent the gain to the multistrategy
        uint256 actualMultistrategyAssets = IERC4626(address(multistrategy)).totalAssets();
        uint256 expectedMultistrategyAssets = 900 * 10 ** decimals;
        assertEq(actualMultistrategyAssets, expectedMultistrategyAssets, "withdraw, multistrategy assets");
    }
}