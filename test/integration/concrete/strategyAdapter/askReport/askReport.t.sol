// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.8.20 <0.9.0;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { StrategyAdapter_Integration_Shared_Test } from "../../../shared/StrategyAdapter.t.sol";
import { IStrategyAdapterMock } from "../../../../shared/TestInterfaces.sol";
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
        IStrategyAdapterMock(address(strategy)).setStakingSlippage(1_500);

        // Request a credit from the multistrategy
        requestCredit(address(strategy), 1_000 ether);

        // Earn some tokens so we can test the slippage when withdrawing the gain
        IStrategyAdapterMock(address(strategy)).earn(100 ether);

        swapCaller(address(multistrategy));

        // Expect a revert
        vm.expectRevert(abi.encodeWithSelector(Errors.SlippageCheckFailed.selector, 90 ether, 85 ether));
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
        requestCredit(address(strategy), 1_000 ether);
        IStrategyAdapterMock(address(strategy)).earn(100 ether);

        swapCaller(address(multistrategy));
        strategy.askReport();

        // Assert the gain gets withdrawn from the underlying strategy
        uint256 actualUnderlyingStrategyBalance = IStrategyAdapterMock(address(strategy)).stakingBalance();
        uint256 expectedUnderlyingStrategyBalance = 1000 ether;
        assertEq(actualUnderlyingStrategyBalance, expectedUnderlyingStrategyBalance, "askReport, underlying strategy balance");

        // Assert the gain gets transfered to the multistrategy
        uint256 actualMultistrategyBalance = IERC20(strategy.baseAsset()).balanceOf(address(multistrategy));
        uint256 expectedMultistrategyBalance = 95 ether;
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
        requestCredit(address(strategy), 1_000 ether);
        IStrategyAdapterMock(address(strategy)).lose(100 ether);

        swapCaller(address(multistrategy));
        strategy.askReport();

        // Assert the multistrategy doesn't get any gain
        uint256 actualMultistrategyBalance = IERC20(strategy.baseAsset()).balanceOf(address(multistrategy));
        uint256 expectedMultistrategyBalance = 0 ether;
        assertEq(actualMultistrategyBalance, expectedMultistrategyBalance, "sendReportPanicked, multistrategy balance");

        // Assert the strategy has the same balance of totalAssets as totalDebt
        uint256 actualStrategyDebt = multistrategy.getStrategyParameters(address(strategy)).totalDebt;
        uint256 actualStrategyTotalAssets = strategy.totalAssets();
        assertEq(actualStrategyDebt, actualStrategyTotalAssets, "sendReportPanicked, assets and debt match");
    }
}