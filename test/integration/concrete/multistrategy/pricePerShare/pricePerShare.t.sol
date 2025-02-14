// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.20 <0.9.0;

import { IERC4626, Multistrategy_Integration_Shared_Test } from "../../../shared/Multistrategy.t.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import { StrategyAdapterMock } from "../../../../mocks/StrategyAdapterMock.sol";

contract PricePerShare_Integration_Concrete_Test is Multistrategy_Integration_Shared_Test {
    StrategyAdapterMock strategy;

    uint8 decimals;

    function setUp() public virtual override {
        Multistrategy_Integration_Shared_Test.setUp();
        decimals = IERC20Metadata(IERC4626(address(multistrategy)).asset()).decimals();
    }
    function test_PricePerShare_ZeroTotalSupply() external view {
        // Assert pricePerShare is 1e18
        uint256 actualPricePerShare = multistrategy.pricePerShare();
        uint256 expectedPricePerShare = 1  * 10 ** decimals;
        assertEq(actualPricePerShare, expectedPricePerShare, "pricePerShare");
    }

    modifier whenTotalSupplyHigherThanZero() {
        // Only way to grow total supply is via a deposit
        triggerUserDeposit(users.bob, 1_000 * 10 ** decimals);
        _;
    }

    function test_PricePerShare_NoProfit() 
        external
        whenTotalSupplyHigherThanZero
    {
        uint256 actualPricePerShare = multistrategy.pricePerShare();
        uint256 expectedPricePerShare = 1 * 10 ** decimals;
        assertEq(actualPricePerShare, expectedPricePerShare, "pricePerShare");
    }

    modifier whenThereIsLockedProfit() {
        // Add the strategy to the multistrategy
        strategy = deployMockStrategyAdapter(address(multistrategy), IERC4626(address(multistrategy)).asset());
        multistrategy.addStrategy(address(strategy), 5_000, 100 * 10 ** decimals, 100_000 * 10 ** decimals);

        strategy.requestCredit();
        // Strategy makes a gain
        triggerStrategyGain(strategy, 100 * 10 ** decimals);
        _;
    }

    function test_PricePerShare_Profit()
        external
        whenTotalSupplyHigherThanZero
        whenThereIsLockedProfit
    {
        // At this point, there is no profit, so pricePerShare should be 1
        uint256 actualPricePerShare = multistrategy.pricePerShare();
        uint256 expectedPricePerShare = 1 * 10 ** decimals;
        assertEq(actualPricePerShare, expectedPricePerShare, "pricePerShare");

        strategy.sendReport(0);
        vm.warp(block.timestamp + 3 days);

        // At this point, all profit is unlocked, so price per share should be higher
        actualPricePerShare = multistrategy.pricePerShare();
        // Strategy made 10% gain, but multistrategy profit is 9,5%, as it already deducted fees.
        expectedPricePerShare = (1095 * 10 ** (decimals - 3)); 
        assertApproxEqAbs(actualPricePerShare, expectedPricePerShare, 1, "pricePerShare");

        // Assert that Alice has less than 1_000 * 10 ** decimals shares
        uint256 aliceShares = IERC20(address(multistrategy)).balanceOf(users.alice);
        uint256 maxExpectedShares = 1_000 * 1e18;
        assertLt(aliceShares, maxExpectedShares, "Alice should have less than 1_000 shares");
    }
}