// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.20 <0.9.0;

import { IERC4626, Multistrategy_Integration_Shared_Test} from "../../../shared/Multistrategy.t.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import { StrategyAdapterMock } from "../../../../mocks/StrategyAdapterMock.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

contract PreviewRedeem_Integration_Concrete_Test is Multistrategy_Integration_Shared_Test {
    using Math for uint256;

    uint8 decimals;

    function setUp() public virtual override {
        Multistrategy_Integration_Shared_Test.setUp();
        decimals = IERC20Metadata(IERC4626(address(multistrategy)).asset()).decimals();
    }

    function test_PreviewRedeem_ZeroShares() external view {
        uint256 actualAssets = IERC4626(address(multistrategy)).previewRedeem(0);
        uint256 expectedAssets = 0;
        assertEq(actualAssets, expectedAssets, "preview redeem");
    }

    modifier whenSharesNotZero() {
        triggerUserDeposit(users.bob, 1000 * 10 ** decimals);
        _;
    }

    function test_PreviewRedeem_EnoughLiquidity()
        external
        whenSharesNotZero
    {
        uint256 shares = 500 ether;

        uint256 actualAssets = IERC4626(address(multistrategy)).previewRedeem(shares);
        uint256 expectedAssets = IERC4626(address(multistrategy)).convertToAssets(shares);
        assertEq(actualAssets, expectedAssets, "preview redeem");
    }

    modifier whenNotEnoughLiquidity() {
        StrategyAdapterMock strategy = deployMockStrategyAdapter(address(multistrategy), IERC4626(address(multistrategy)).asset());
        multistrategy.addStrategy(address(strategy), 6_000, 0, 100_000 * 10 ** decimals);
        strategy.requestCredit();
        _;
    }

    function test_PreviewRedeem_SlippageLimitZero()
        external
        whenSharesNotZero
        whenNotEnoughLiquidity
    {
        uint256 shares = 500 ether;

        uint256 actualAssets = IERC4626(address(multistrategy)).previewRedeem(shares);
        uint256 expectedAssets = IERC4626(address(multistrategy)).convertToAssets(shares);
        assertEq(actualAssets, expectedAssets, "preview redeem");
    }

    modifier whenSlippageLimitNotZero() {
        multistrategy.setSlippageLimit(100);
        _;
    }

    function test_PreviewRedeem_SlippageLimitNotZero()
        external
        whenSharesNotZero
        whenNotEnoughLiquidity
        whenSlippageLimitNotZero
    {
        uint256 shares = 500 ether;

        uint256 actualAssets = IERC4626(address(multistrategy)).previewRedeem(shares);
        uint256 expectedAssets = IERC4626(address(multistrategy)).convertToAssets(shares.mulDiv(9_900, 10_000));
        assertEq(actualAssets, expectedAssets, "preview redeem");
    }
}