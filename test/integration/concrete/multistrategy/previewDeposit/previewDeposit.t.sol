// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.20 <0.9.0;

import { IERC4626, Multistrategy_Integration_Shared_Test } from "../../../shared/Multistrategy.t.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import { IStrategyAdapter } from "interfaces/infra/multistrategy/IStrategyAdapter.sol";
import { IStrategyAdapterMock } from "../../../../shared/TestInterfaces.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

contract PreviewDeposit_Integration_Concrete_Test is Multistrategy_Integration_Shared_Test {
    using Math for uint256;

    address strategy;
    uint256 slippage = 100;
    uint8 decimals;

    function setUp() public virtual override {
        Multistrategy_Integration_Shared_Test.setUp();
        decimals = IERC20Metadata(IERC4626(address(multistrategy)).asset()).decimals();
    }

    function test_PreviewDeposit_ZeroAssets() external {
        uint256 actualShares = IERC4626(address(multistrategy)).previewDeposit(0);
        uint256 expectedShares = 0;
        assertEq(actualShares, expectedShares, "preview deposit");
    }

    modifier whenAssetsNotZero() {
        triggerUserDeposit(users.bob, 1000 * 10 ** decimals);
        _;
    }

    function test_PreviewDeposit()
        external
        whenAssetsNotZero
    {
        uint256 assets = 500 * 10 ** decimals;

        uint256 actualShares = IERC4626(address(multistrategy)).previewDeposit(assets);
        uint256 expectedShares = IERC4626(address(multistrategy)).convertToShares(assets);
        assertEq(actualShares, expectedShares, "preview deposit");
    }

    modifier whenThereIsActiveStrategy() {
        strategy = deployMockStrategyAdapter(address(multistrategy), IERC4626(address(multistrategy)).asset());
        multistrategy.addStrategy(strategy, 10_000, 0, 100_000 * 10 ** decimals);
        IStrategyAdapter(strategy).requestCredit();
        _;
    }

    function test_PreviewDeposit_MatchesShares_NoProfit() 
        external 
        whenAssetsNotZero 
        whenThereIsActiveStrategy
    {
        uint256 assets = 500 * 10 ** decimals;
        deal(IERC4626(address(multistrategy)).asset(), users.bob, assets);
        

        uint256 previewedShares = IERC4626(address(multistrategy)).previewDeposit(assets);
        swapCaller(users.bob); asset.approve(address(multistrategy), assets);
        swapCaller(users.bob); uint256 actualShares = IERC4626(address(multistrategy)).deposit(assets, users.bob);

        assertGe(actualShares, previewedShares, "preview deposit should match actual shares when no profit is made");
    }

    modifier whenActiveStrategyMadeProfit() {
        IStrategyAdapterMock(strategy).earn(100 * 10 ** decimals);
        _;
    }

    function test_PreviewDeposit_MatchesShares_WithProfit()
        external 
        whenAssetsNotZero 
        whenThereIsActiveStrategy
        whenActiveStrategyMadeProfit

    {
        uint256 assets = 500 * 10 ** decimals;
        deal(IERC4626(address(multistrategy)).asset(), users.bob, assets);

        uint256 previewedShares = IERC4626(address(multistrategy)).previewDeposit(assets);
        swapCaller(users.bob); asset.approve(address(multistrategy), assets);
        swapCaller(users.bob); uint256 actualShares = IERC4626(address(multistrategy)).deposit(assets, users.bob);

        // Check if the previewed shares match the actual shares received
        assertGe(actualShares, previewedShares, "preview deposit should match actual shares when profit is made");
    }

    modifier whenActiveStrategyMadeLoss() {
        IStrategyAdapterMock(strategy).lose(100 * 10 ** decimals);
        _;
    }

    function test_PreviewDeposit_MatchesShares_WithLoss()
        external 
        whenAssetsNotZero 
        whenThereIsActiveStrategy
        whenActiveStrategyMadeLoss

    {
        uint256 assets = 500 * 10 ** decimals;
        deal(IERC4626(address(multistrategy)).asset(), users.bob, assets);

        uint256 previewedShares = IERC4626(address(multistrategy)).previewDeposit(assets);
        swapCaller(users.bob); asset.approve(address(multistrategy), assets);
        swapCaller(users.bob); uint256 actualShares = IERC4626(address(multistrategy)).deposit(assets, users.bob);

        // Check if the previewed shares match the actual shares received
        assertGe(actualShares, previewedShares, "preview deposit should match actual shares when loss is made");
    }
}