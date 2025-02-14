// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.8.20 <0.9.0;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import { IERC4626, StrategyAdapter_Integration_Shared_Test } from "../../../shared/StrategyAdapter.t.sol";
import { Errors } from "src/infra/libraries/Errors.sol";

contract TryWithdraw_Integration_Concrete_Test is StrategyAdapter_Integration_Shared_Test {
    function test_TryWithdraw_ZeroAmount() external {
        strategy.tryWithdraw(0);

        uint256 actualWithdraw = IERC20(asset).balanceOf(address(strategy));
        uint256 expectedWithdrawn = 0;
        assertEq(actualWithdraw, expectedWithdrawn, "tryWithdraw, zero amount");
    }

    modifier whenAmountGreaterThanZero() {
        _;
    }
    
    function test_RevertWhen_CurrentBalanceLowerThanDesiredBalance() 
        external
        whenAmountGreaterThanZero
    {   
        // Set slippage limit to 10%
        strategy.setSlippageLimit(1000);

        // Set staking slippage to 15%
        strategy.setStakingSlippage(1500);
        requestCredit(strategy, 1000 * 10 ** decimals);

        // Expect a revert
        vm.expectRevert(abi.encodeWithSelector(Errors.SlippageCheckFailed.selector, 900 * 10 ** decimals, 850 * 10 ** decimals));
        strategy.tryWithdraw(1000 * 10 ** decimals);
    }

    modifier whenCurrentBalanceHigherThanDesiredBalance() {
        _;
    }

    function test_Withdraw() 
        external
        whenAmountGreaterThanZero
        whenCurrentBalanceHigherThanDesiredBalance
    {
        requestCredit(strategy, 1000 * 10 ** decimals);

        strategy.tryWithdraw(1000 * 10 ** decimals);

        uint256 actualWithdraw = IERC20(asset).balanceOf(address(strategy));
        uint256 expectedWithdrawn = 1000 * 10 ** decimals;
        assertEq(actualWithdraw, expectedWithdrawn, "tryWithdraw, zero amount");
    }
}