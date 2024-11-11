// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.20 <0.9.0;

import {console} from "forge-std/console.sol";
import { IERC4626, Multistrategy_Integration_Shared_Test } from "../../../shared/Multistrategy.t.sol";
import { IStrategyAdapter } from "interfaces/infra/multistrategy/IStrategyAdapter.sol";
import { IStrategyAdapterMock } from "../../../../shared/TestInterfaces.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

contract PreviewDeposit_Integration_Concrete_Test is Multistrategy_Integration_Shared_Test {
    using Math for uint256;

    address strategy;
    uint256 slippage = 100;

    function test_PreviewDeposit_ZeroAssets() external {
        uint256 actualShares = IERC4626(address(multistrategy)).previewDeposit(0);
        uint256 expectedShares = 0;
        assertEq(actualShares, expectedShares, "preview deposit");
    }

    modifier whenAssetsNotZero() {
        triggerUserDeposit(users.bob, 1000 ether);
        _;
    }

    function test_PreviewDeposit()
        external
        whenAssetsNotZero
    {
        uint256 assets = 500 ether;

        uint256 actualShares = IERC4626(address(multistrategy)).previewDeposit(assets);
        uint256 expectedShares = IERC4626(address(multistrategy)).convertToShares(assets);
        assertEq(actualShares, expectedShares, "preview deposit");
    }

    modifier whenThereIsActiveStrategy() {
        strategy = deployMockStrategyAdapter(address(multistrategy), IERC4626(address(multistrategy)).asset());
        multistrategy.addStrategy(strategy, 10_000, 0, 100_000 ether);
        IStrategyAdapter(strategy).requestCredit();
        _;
    }

    function test_PreviewDeposit_MatchesShares_NoProfit() 
        external 
        whenAssetsNotZero 
        whenThereIsActiveStrategy
    {
        uint256 assets = 500 ether;
        deal(IERC4626(address(multistrategy)).asset(), users.bob, assets);
        

        uint256 previewedShares = IERC4626(address(multistrategy)).previewDeposit(assets);
        swapCaller(users.bob); asset.approve(address(multistrategy), assets);
        swapCaller(users.bob); uint256 actualShares = IERC4626(address(multistrategy)).deposit(assets, users.bob);

        assertEq(actualShares, previewedShares, "preview deposit should match actual shares when no profit is made");
    }

    modifier whenActiveStrategyMadeProfit() {
        IStrategyAdapterMock(strategy).earn(100 ether);
        _;
    }

    function test_PreviewDeposit_MatchesShares_WithProfit()
        external 
        whenAssetsNotZero 
        whenThereIsActiveStrategy
        whenActiveStrategyMadeProfit

    {
        uint256 assets = 500 ether;
        deal(IERC4626(address(multistrategy)).asset(), users.bob, assets);

        uint256 previewedShares = IERC4626(address(multistrategy)).previewDeposit(assets);
        swapCaller(users.bob); asset.approve(address(multistrategy), assets);
        swapCaller(users.bob); uint256 actualShares = IERC4626(address(multistrategy)).deposit(assets, users.bob);

        // Check if the previewed shares match the actual shares received
        assertEq(actualShares, previewedShares, "preview deposit should match actual shares when profit is made");

        console.log(actualShares, previewedShares);
    }

    modifier whenActiveStrategyMadeLoss() {
        IStrategyAdapterMock(strategy).lose(100 ether);
        _;
    }

    function test_PreviewDeposit_MatchesShares_WithLoss()
        external 
        whenAssetsNotZero 
        whenThereIsActiveStrategy
        whenActiveStrategyMadeLoss

    {
        uint256 assets = 500 ether;
        deal(IERC4626(address(multistrategy)).asset(), users.bob, assets);

        uint256 previewedShares = IERC4626(address(multistrategy)).previewDeposit(assets);
        swapCaller(users.bob); asset.approve(address(multistrategy), assets);
        swapCaller(users.bob); uint256 actualShares = IERC4626(address(multistrategy)).deposit(assets, users.bob);

        // Check if the previewed shares match the actual shares received
        assertEq(actualShares, previewedShares, "preview deposit should match actual shares when loss is made");
    }
}