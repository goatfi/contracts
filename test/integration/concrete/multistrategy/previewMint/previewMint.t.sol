// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.20 <0.9.0;

import { IERC4626, Multistrategy_Integration_Shared_Test } from "../../../shared/Multistrategy.t.sol";
import { IStrategyAdapter } from "interfaces/infra/multistrategy/IStrategyAdapter.sol";
import { IStrategyAdapterMock } from "../../../../shared/TestInterfaces.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

contract PreviewMint_Integration_Concrete_Test is Multistrategy_Integration_Shared_Test {
    using Math for uint256;

    address strategy;
    uint256 slippage = 100;

    function test_PreviewMint_ZeroShares() external {
        uint256 actualAssets = IERC4626(address(multistrategy)).previewMint(0);
        uint256 expectedAssets = 0;
        assertEq(actualAssets, expectedAssets, "preview mint");
    }

    modifier whenSharesNotZero() {
        triggerUserDeposit(users.bob, 1000 ether);
        _;
    }

    function test_PreviewMint()
        external
        whenSharesNotZero
    {
        uint256 shares = 500 ether;

        uint256 actualAssets = IERC4626(address(multistrategy)).previewMint(shares);
        uint256 expectedAssets = IERC4626(address(multistrategy)).convertToAssets(shares);
        assertEq(actualAssets, expectedAssets, "preview mint");
    }

    modifier whenThereIsActiveStrategy() {
        strategy = deployMockStrategyAdapter(address(multistrategy), IERC4626(address(multistrategy)).asset());
        multistrategy.addStrategy(strategy, 10_000, 0, 100_000 ether);
        IStrategyAdapter(strategy).requestCredit();
        _;
    }

    function test_PreviewMint_MatchesAssets_NoProfit() 
        external 
        whenSharesNotZero 
        whenThereIsActiveStrategy
    {
        uint256 shares = 500 ether;
        deal(IERC4626(address(multistrategy)).asset(), users.bob, shares);

        uint256 previewedShares = IERC4626(address(multistrategy)).previewMint(shares);
        swapCaller(users.bob); asset.approve(address(multistrategy), type(uint256).max);
        swapCaller(users.bob); uint256 actualShares = IERC4626(address(multistrategy)).mint(shares, users.bob);

        // Check if the previewed shares match the actual shares received
        assertEq(actualShares, previewedShares, "preview mint should match actual shares when profit is made");
    }

    modifier whenActiveStrategyMadeProfit() {
        IStrategyAdapterMock(strategy).earn(100 ether);
        _;
    }

    function test_PreviewMint_MatchesAssets_WithProfit()
        external 
        whenSharesNotZero 
        whenThereIsActiveStrategy
        whenActiveStrategyMadeProfit

    {
        uint256 shares = 500 ether;
        deal(IERC4626(address(multistrategy)).asset(), users.bob, shares * 2);

        uint256 previewedAssets = IERC4626(address(multistrategy)).previewMint(shares);
        swapCaller(users.bob); asset.approve(address(multistrategy), type(uint256).max);
        swapCaller(users.bob); uint256 actualAssets = IERC4626(address(multistrategy)).mint(shares, users.bob);

        // Check if the previewed shares match the actual shares received
        assertEq(actualAssets, previewedAssets, "preview mint should match actual shares when profit is made");
    }

    modifier whenActiveStrategyMadeLoss() {
        IStrategyAdapterMock(strategy).lose(100 ether);
        _;
    }

    function test_PreviewMint_MatchesAssets_WithLoss()
        external 
        whenSharesNotZero 
        whenThereIsActiveStrategy
        whenActiveStrategyMadeLoss

    {
        uint256 shares = 500 ether;
        deal(IERC4626(address(multistrategy)).asset(), users.bob, shares);

        uint256 previewedShares = IERC4626(address(multistrategy)).previewMint(shares);
        swapCaller(users.bob); asset.approve(address(multistrategy), type(uint256).max);
        swapCaller(users.bob); uint256 actualShares = IERC4626(address(multistrategy)).mint(shares, users.bob);

        // Check if the previewed shares match the actual shares received
        assertEq(actualShares, previewedShares, "preview mint should match actual shares when profit is made");
    }
}