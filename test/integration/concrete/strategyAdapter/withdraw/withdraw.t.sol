// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.8.20 <0.9.0;

import { StrategyAdapter_Integration_Shared_Test } from "../../../shared/StrategyAdapter.t.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";
import { Errors } from "src/infra/libraries/Errors.sol";

contract Withdraw_Integration_Concrete_Test is StrategyAdapter_Integration_Shared_Test {
    function test_RevertWhen_CallerNotMultistrategy() external {
        // Change caller to bob
        swapCaller(users.bob);

        // Expect it to revert
        vm.expectRevert(abi.encodeWithSelector(Errors.CallerNotMultistrategy.selector, users.bob));
        strategy.withdraw(1_000 ether);
    }

    modifier whenCallerMultistrategy() {
        _;
    }

    function test_RevertWhen_ContractPaused() external whenCallerMultistrategy {
        strategy.pause();

        swapCaller(address(multistrategy));
        
        // Expect it to revert
        vm.expectRevert(abi.encodeWithSelector(Pausable.EnforcedPause.selector));
        strategy.withdraw(1_000 ether);
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
        strategySlippage.setSlippageLimit(1_000);

        // Set the staking slippage to be 15%
        strategySlippage.setStakingSlippage(1_500);

        // Request a credit from the multistrategy
        requestCredit(address(strategySlippage), 1_000 ether);

        swapCaller(address(multistrategy));

        // Expect a revert
        vm.expectRevert(abi.encodeWithSelector(Errors.SlippageCheckFailed.selector, 900 ether, 850 ether));
        strategySlippage.withdraw(1_000 ether);
    }

    modifier whenSlippageLimitRespected() {
        _;
    }

    function test_Withdraw() 
        external
        whenCallerMultistrategy
        whenContractNotPaused
        whenSlippageLimitRespected
    {
        // Set the slippage limit of the strategy to 1%
        strategySlippage.setSlippageLimit(100);

        // Set the staking slippage to be 0.5%
        strategySlippage.setStakingSlippage(50);

        // Request a credit from the multistrategy
        requestCredit(address(strategySlippage), 1_000 ether);

        // Make a withdraw
        swapCaller(address(multistrategy));
        strategySlippage.withdraw(1_000 ether);

        // Assert the strategy no longer has the assets
        uint256 actualStrategyAssets = strategySlippage.totalAssets();
        uint256 expectedStrategyAssets = 0;
        assertEq(actualStrategyAssets, expectedStrategyAssets, "withdraw, strategy assets");

        // Assert the multistrategy has the assets in balance
        uint256 actualMultistrategyAssets = dai.balanceOf(address(multistrategy));
        uint256 expectedMultistrategyAssets = 995 ether;
        assertEq(actualMultistrategyAssets, expectedMultistrategyAssets, "withdraw, multistrategy balance");
    }
}