// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.20 <0.9.0;

import { IERC4626, Multistrategy_Integration_Shared_Test} from "../../../shared/Multistrategy.t.sol";
import {IStrategyAdapter} from "interfaces/infra/multistrategy/IStrategyAdapter.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

contract PreviewWithdraw_Integration_Concrete_Test is Multistrategy_Integration_Shared_Test {
    using Math for uint256;

    uint256 slippage = 100;

    function test_PreviewWithdraw_ZeroAssets() external {
        uint256 actualShares = IERC4626(address(multistrategy)).previewWithdraw(0);
        uint256 expectedShares = 0;
        assertEq(actualShares, expectedShares, "preview withdraw");
    }

    modifier whenAssetsNotZero() {
        triggerUserDeposit(users.bob, 1000 ether);
        _;
    }

    function test_PreviewWithdraw_EnoughLiquidity()
        external
        whenAssetsNotZero
    {
        uint256 assets = 500 ether;

        uint256 actualShares = IERC4626(address(multistrategy)).previewWithdraw(assets);
        uint256 expectedShares = IERC4626(address(multistrategy)).convertToShares(assets);
        assertEq(actualShares, expectedShares, "preview withdraw");
    }

    modifier whenNotEnoughLiquidity() {
        address strategy = deployMockStrategyAdapter(address(multistrategy), IERC4626(address(multistrategy)).asset());
        multistrategy.addStrategy(strategy, 6_000, 0, 100_000 ether);
        IStrategyAdapter(strategy).requestCredit();
        _;
    }

    function test_PreviewWithdraw_SlippageLimitZero()
        external
        whenAssetsNotZero
        whenNotEnoughLiquidity
    {
        uint256 assets = 500 ether;

        uint256 actualShares = IERC4626(address(multistrategy)).previewWithdraw(assets);
        uint256 expectedShares = IERC4626(address(multistrategy)).convertToShares(assets);
        assertEq(actualShares, expectedShares, "preview withdraw");
    }

    modifier whenSlippageLimitNotZero() {
        multistrategy.setSlippageLimit(10_000);
        _;
    }

    function test_PreviewWithdraw_SlippageMAXBPS()
        external
        whenAssetsNotZero
        whenNotEnoughLiquidity
        whenSlippageLimitNotZero
    {
        uint256 assets = 500 ether;
        multistrategy.setSlippageLimit(10_000);

        uint256 actualShares = IERC4626(address(multistrategy)).previewWithdraw(assets);
        uint256 expectedShares = type(uint256).max;
        assertEq(actualShares, expectedShares, "preview withdraw");
    }

    modifier whenSlippageLimitNotMAXBPS() {
        multistrategy.setSlippageLimit(slippage);
        _;
    }

    function test_PreviewWithdraw_SlippageLimitNotZero()
        external
        whenAssetsNotZero
        whenNotEnoughLiquidity
        whenSlippageLimitNotZero
        whenSlippageLimitNotMAXBPS
    {
        uint256 assets = 500 ether;
        uint256 assetsWithSlippage = assets.mulDiv(10_000, 10_000 - slippage, Math.Rounding.Ceil);

        uint256 actualShares = IERC4626(address(multistrategy)).previewWithdraw(assets);
        uint256 expectedShares = IERC4626(address(multistrategy)).convertToShares(assetsWithSlippage);
        assertEq(actualShares, expectedShares, "preview withdraw");
    }
}