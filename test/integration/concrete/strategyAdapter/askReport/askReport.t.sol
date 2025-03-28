// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.8.20 <0.9.0;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import { IERC4626, StrategyAdapter_Integration_Shared_Test } from "../../../shared/StrategyAdapter.t.sol";
import { StrategyAdapterMock } from "../../../../mocks/StrategyAdapterMock.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";
import { Errors } from "src/infra/libraries/Errors.sol";

contract AskReport_Integration_Concrete_Test is StrategyAdapter_Integration_Shared_Test {
    function test_RevertWhen_CallerNotMultistrategy() external {
        // Change caller to bob
        swapCaller(users.bob);

        // Expect it to revert
        vm.expectRevert(abi.encodeWithSelector(Errors.CallerNotMultistrategy.selector, users.bob));
        strategy.askReport();
    }

    modifier whenCallerMultistrategy() {
        _;
    }

    function test_RevertWhen_ContractPaused() external whenCallerMultistrategy {
        strategy.pause();

        swapCaller(address(multistrategy));
        
        // Expect it to revert
        vm.expectRevert(abi.encodeWithSelector(Pausable.EnforcedPause.selector));
        strategy.askReport();
    }

    modifier whenContractNotPaused() {
        _;
    }

    function test_RevertWhen_SlippageLimitExceeded() 
        external
        whenCallerMultistrategy
        whenContractNotPaused
    {
        // Set the slippage limit of the strategy to 10%
        strategy.setSlippageLimit(1_000);

        // Set the staking slippage to be 15%
        strategy.setStakingSlippage(1_500);

        // Request a credit from the multistrategy
        requestCredit(strategy, 1_000 * 10 ** decimals);

        // Earn some tokens so we can test the slippage when withdrawing the gain
        (strategy).earn(100 * 10 ** decimals);

        swapCaller(address(multistrategy));

        // Expect a revert
        vm.expectRevert(abi.encodeWithSelector(Errors.SlippageCheckFailed.selector, 90 * 10 ** decimals, 85 * 10 ** decimals));
        strategy.askReport();
    }

    modifier whenSlippageLimitRespected() {
        _;
    }

    function test_AskReport_Gain() 
        external
        whenCallerMultistrategy
        whenContractNotPaused
        whenSlippageLimitRespected
    {
        requestCredit(strategy, 1_000 * 10 ** decimals);
        strategy.earn(100 * 10 ** decimals);

        swapCaller(address(multistrategy));
        strategy.askReport();

        // Assert the gain gets withdrawn from the underlying strategy
        uint256 actualUnderlyingStrategyBalance = strategy.stakingBalance();
        uint256 expectedUnderlyingStrategyBalance = 1000 * 10 ** decimals;
        assertEq(actualUnderlyingStrategyBalance, expectedUnderlyingStrategyBalance, "askReport, underlying strategy balance");

        // Assert the gain gets transferred to the multistrategy
        uint256 actualMultistrategyBalance = IERC20(strategy.asset()).balanceOf(address(multistrategy));
        uint256 expectedMultistrategyBalance = 95 * 10 ** decimals;
        assertEq(actualMultistrategyBalance, expectedMultistrategyBalance, "sendReportPanicked, multistrategy balance");

        // Assert the strategy has the same balance of totalAssets as totalDebt
        uint256 actualStrategyDebt = multistrategy.getStrategyParameters(address(strategy)).totalDebt;
        uint256 actualStrategyTotalAssets = strategy.totalAssets();
        assertEq(actualStrategyDebt, actualStrategyTotalAssets, "sendReportPanicked, assets and debt match");
    }

    function test_AskReport_Loss()
        external
        whenCallerMultistrategy
        whenContractNotPaused
        whenSlippageLimitRespected
    {
        requestCredit(strategy, 1_000 * 10 ** decimals);
        strategy.lose(100 * 10 ** decimals);

        swapCaller(address(multistrategy));
        strategy.askReport();

        // Assert the multistrategy doesn't get any gain
        uint256 actualMultistrategyBalance = IERC20(strategy.asset()).balanceOf(address(multistrategy));
        uint256 expectedMultistrategyBalance = 0 * 10 ** decimals;
        assertEq(actualMultistrategyBalance, expectedMultistrategyBalance, "sendReportPanicked, multistrategy balance");

        // Assert the strategy has the same balance of totalAssets as totalDebt
        uint256 actualStrategyDebt = multistrategy.getStrategyParameters(address(strategy)).totalDebt;
        uint256 actualStrategyTotalAssets = strategy.totalAssets();
        assertEq(actualStrategyDebt, actualStrategyTotalAssets, "sendReportPanicked, assets and debt match");
    }
}