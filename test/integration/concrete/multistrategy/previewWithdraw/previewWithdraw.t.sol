// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.20 <0.9.0;

import { IERC4626, Multistrategy_Integration_Shared_Test} from "../../../shared/Multistrategy.t.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import { StrategyAdapterMock } from "../../../../mocks/StrategyAdapterMock.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

contract PreviewWithdraw_Integration_Concrete_Test is Multistrategy_Integration_Shared_Test {
    using Math for uint256;

    uint256 slippage = 100;

    uint8 decimals;

    function setUp() public virtual override {
        Multistrategy_Integration_Shared_Test.setUp();
        decimals = IERC20Metadata(IERC4626(address(multistrategy)).asset()).decimals();
    }

    function test_PreviewWithdraw_ZeroAssets() external view {
        uint256 actualShares = IERC4626(address(multistrategy)).previewWithdraw(0);
        uint256 expectedShares = 0;
        assertEq(actualShares, expectedShares, "preview withdraw");
    }

    modifier whenAssetsNotZero() {
        triggerUserDeposit(users.bob, 1000 * 10 ** decimals);
        _;
    }

    function test_PreviewWithdraw_EnoughLiquidity()
        external
        whenAssetsNotZero
    {
        uint256 assets = 500 * 10 ** decimals;

        uint256 actualShares = IERC4626(address(multistrategy)).previewWithdraw(assets);
        uint256 expectedShares = IERC4626(address(multistrategy)).convertToShares(assets);
        assertEq(actualShares, expectedShares, "preview withdraw");
    }

    modifier whenNotEnoughLiquidity() {
        StrategyAdapterMock strategy = deployMockStrategyAdapter(address(multistrategy), IERC4626(address(multistrategy)).asset());
        multistrategy.addStrategy(address(strategy), 6_000, 0, 100_000 * 10 ** decimals);
        strategy.requestCredit();
        _;
    }

    function test_PreviewWithdraw_SlippageLimitZero()
        external
        whenAssetsNotZero
        whenNotEnoughLiquidity
    {
        uint256 assets = 500 * 10 ** decimals;

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
        uint256 assets = 500 * 10 ** decimals;
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
        uint256 assets = 500 * 10 ** decimals;
        uint256 shares = IERC4626(address(multistrategy)).convertToShares(assets);

        uint256 actualShares = IERC4626(address(multistrategy)).previewWithdraw(assets);
        uint256 expectedShares = shares.mulDiv(10_000, 10_000 - slippage, Math.Rounding.Ceil);
        assertEq(actualShares, expectedShares, "preview withdraw");
    }
}