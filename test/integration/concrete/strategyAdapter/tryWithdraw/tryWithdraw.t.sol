// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.8.20 <0.9.0;

import { StrategyAdapter_Integration_Shared_Test } from "../../../shared/StrategyAdapter.t.sol";
import { IStrategyAdapterMock } from "../../../../shared/TestInterfaces.sol";
import { Errors } from "src/infra/libraries/Errors.sol";

contract TryWithdraw_Integration_Concrete_Test is StrategyAdapter_Integration_Shared_Test {
    function test_TryWithdraw_ZeroAmount() external {
        uint256 withdrawn = IStrategyAdapterMock(address(strategy)).tryWithdraw(0);

        uint256 actualWithdraw = withdrawn;
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
        IStrategyAdapterMock(address(strategy)).setStakingSlippage(1500);
        requestCredit(address(strategy), 1000 ether);

        // Expect a revert
        vm.expectRevert(abi.encodeWithSelector(Errors.SlippageCheckFailed.selector, 900 ether, 850 ether));
        IStrategyAdapterMock(address(strategy)).tryWithdraw(1000 ether);
    }

    modifier whenCurrentBalanceHigherThanDesiredBalance() {
        _;
    }

    function test_Withdraw() 
        external
        whenAmountGreaterThanZero
        whenCurrentBalanceHigherThanDesiredBalance
    {
        requestCredit(address(strategy), 1000 ether);

        uint256 withdrawn = IStrategyAdapterMock(address(strategy)).tryWithdraw(1000 ether);

        uint256 actualWithdraw = withdrawn;
        uint256 expectedWithdrawn = 1000 ether;
        assertEq(actualWithdraw, expectedWithdrawn, "tryWithdraw, zero amount");
    }
}