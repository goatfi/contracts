// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.20 <0.9.0;

import { IERC4626, Multistrategy_Integration_Shared_Test } from "../../../shared/Multistrategy.t.sol";
import { IStrategyAdapter } from "interfaces/infra/multistrategy/IStrategyAdapter.sol";

contract PricePerShare_Integration_Concrete_Test is Multistrategy_Integration_Shared_Test {
    address strategy;
    function test_PricePerShare_ZeroTotalSupply() external {
        // Assert pricePerShare is 1e18
        uint256 actualPricePerShare = multistrategy.pricePerShare();
        uint256 expectedPricePerShare = 1 ether;
        assertEq(actualPricePerShare, expectedPricePerShare, "pricePerShare");
    }

    modifier whenTotalSupplyHigherThanZero() {
        // Only way to grow total supply is via a deposit
        triggerUserDeposit(users.bob, 1_000 ether);
        _;
    }

    function test_PricePerShare_NoLockedProfit() 
        external
        whenTotalSupplyHigherThanZero
    {
        uint256 actualPricePerShare = multistrategy.pricePerShare();
        uint256 expectedPricePerShare = 1 ether;
        assertEq(actualPricePerShare, expectedPricePerShare, "pricePerShare");
    }

    modifier whenThereIsLockedProfit() {
        // Add the strategy to the multistrategy
        strategy = deployMockStrategyAdapter(address(multistrategy), IERC4626(address(multistrategy)).asset());
        multistrategy.addStrategy(strategy, 5_000, 100 ether, 100_000 ether);

        // Strategy requests a credit
        IStrategyAdapter(strategy).requestCredit();
        // Strategy makes a gain
        triggerStrategyGain(strategy, 100 ether);
        // Strategy reports back to the multistrategy. It doesn't repay any debt
        IStrategyAdapter(strategy).sendReport(0);
        _;
    }

    function test_PricePerShare_LockedProfit()
        external
        whenTotalSupplyHigherThanZero
        whenThereIsLockedProfit
    {
        // At this point, all profit is locked, so price per share should remain at 1
        uint256 actualPricePerShare = multistrategy.pricePerShare();
        uint256 expectedPricePerShare = 1 ether;
        assertEq(actualPricePerShare, expectedPricePerShare, "pricePerShare");

        vm.warp(block.timestamp + multistrategy.PROFIT_UNLOCK_TIME() + 1);

        // At this point, all profit is unlocked, so price per share should be higher
        actualPricePerShare = multistrategy.pricePerShare();
        // Strategy made 10% gain, but multistrategy profit is 9,5%, as it already deducted fees.
        expectedPricePerShare = 1.095 ether ;
        assertApproxEqAbs(actualPricePerShare, expectedPricePerShare, 1, "pricePerShare");
    }
}