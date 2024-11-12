// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.20 <0.9.0;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC4626, Multistrategy_Integration_Shared_Test } from "../../../shared/Multistrategy.t.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

contract ConvertToAssets_Integration_Concrete_Test is Multistrategy_Integration_Shared_Test {
    uint256 shares;
    uint8 decimals;

    function setUp() public virtual override {
        Multistrategy_Integration_Shared_Test.setUp();
        decimals = IERC20Metadata(IERC4626(address(multistrategy)).asset()).decimals();
        shares = 100 * 10 ** decimals;
    }
    function test_ConvertToAssets_ZeroTotalSupply() external {
        // Assert share value is zero when totalSupply is 0
        uint256 actualAssets = IERC4626(address(multistrategy)).convertToAssets(shares);
        uint256 expectedAssets = shares / (1 * 10 ** (18 - decimals));
        assertEq(actualAssets, expectedAssets, "convertToAssets");
    }

    modifier whenTotalSupplyNotZero() {
        triggerUserDeposit(users.bob, 1000 * 10 ** decimals);
        _;
    }

    function test_ConvertToAssets_ZeroSharesAmount() 
        external
        whenTotalSupplyNotZero
    {
        uint256 actualAssets = IERC4626(address(multistrategy)).convertToAssets(0);
        uint256 expectedAssets = 0;
        assertEq(actualAssets, expectedAssets, "convertToAssets");
    }

    modifier whenSharesAmountNotZero() {
        _;
    }

    function test_ConvertToAssets()
        external
        whenTotalSupplyNotZero
        whenSharesAmountNotZero
    {
        uint256 totalAssets = IERC4626(address(multistrategy)).totalAssets();
        uint256 totalSupply = IERC20(address(multistrategy)).totalSupply();

        // Assert share value is the amount of shares multiplied by freeFunds, divided by totalSupply
        uint256 actualAssets = IERC4626(address(multistrategy)).convertToAssets(shares);
        uint256 expectedAssets = Math.mulDiv(shares, totalAssets + 1, totalSupply + 1, Math.Rounding.Floor);
        assertEq(actualAssets, expectedAssets, "convertToAssets");
    }
}