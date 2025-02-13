// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.8.20 <0.9.0;

import { IERC4626, StrategyAdapter_Integration_Shared_Test } from "../../../shared/StrategyAdapter.t.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";
import { Errors } from "src/infra/libraries/Errors.sol";

contract Withdraw_Integration_Concrete_Test is StrategyAdapter_Integration_Shared_Test {
    function test_RevertWhen_CallerNotMultistrategy() external {
        // Change caller to bob
        swapCaller(users.bob);

        // Expect it to revert
        vm.expectRevert(abi.encodeWithSelector(Errors.CallerNotMultistrategy.selector, users.bob));
        strategy.withdraw(1_000 * 10 ** decimals);
    }

    modifier whenCallerMultistrategy() {
        _;
    }

    function test_RevertWhen_ContractPaused() external whenCallerMultistrategy {
        strategy.pause();

        swapCaller(address(multistrategy));
        
        // Expect it to revert
        vm.expectRevert(abi.encodeWithSelector(Pausable.EnforcedPause.selector));
        strategy.withdraw(1_000 * 10 ** decimals);
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

        swapCaller(address(multistrategy));

        // Expect a revert
        vm.expectRevert(abi.encodeWithSelector(Errors.SlippageCheckFailed.selector, 900 * 10 ** decimals, 850 * 10 ** decimals));
        strategy.withdraw(1_000 * 10 ** decimals);
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
        strategy.setSlippageLimit(100);

        // Set the staking slippage to be 0.5%
        strategy.setStakingSlippage(50);

        // Request a credit from the multistrategy
        requestCredit(strategy, 1_000 * 10 ** decimals);

        // Make a withdraw
        swapCaller(address(multistrategy));
        uint256 withdrawn = strategy.withdraw(1_000 * 10 ** decimals);

        // Assert the strategy no longer has the assets
        uint256 actualStrategyAssets = strategy.totalAssets();
        uint256 expectedStrategyAssets = 0;
        assertEq(actualStrategyAssets, expectedStrategyAssets, "withdraw, strategy assets");

        // Assert the multistrategy has the assets in balance
        uint256 actualMultistrategyAssets = asset.balanceOf(address(multistrategy));
        uint256 expectedMultistrategyAssets = withdrawn;
        assertEq(actualMultistrategyAssets, expectedMultistrategyAssets, "withdraw, multistrategy balance");
    }
}