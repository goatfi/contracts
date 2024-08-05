// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.20 <0.9.0;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC4626, MultistrategyHarness_Integration_Shared_Test } from "../../../shared/MultistrategyHarness.t.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

contract ConvertToAssets_Integration_Concrete_Test is MultistrategyHarness_Integration_Shared_Test {
    uint256 shares = 100 ether;
    function test_ConvertToAssets_ZeroTotalSupply() external {
        // Assert share value is zero when totalSupply is 0
        uint256 actualAssets = IERC4626(address(multistrategyHarness)).convertToAssets(shares);
        uint256 expectedAssets = shares;
        assertEq(actualAssets, expectedAssets, "convertToAssets");
    }

    modifier whenTotalSupplyNotZero() {
        triggerUserDeposit(users.bob, 1000 ether);
        _;
    }

    function test_ConvertToAssets_ZeroSharesAmount() 
        external
        whenTotalSupplyNotZero
    {
        // Assert share value is zero when amount of shares is 0
        uint256 ctualAssets = IERC4626(address(multistrategyHarness)).convertToAssets(0);
        uint256 expectedAssets = 0;
        assertEq(ctualAssets, expectedAssets, "convertToAssets");
    }

    modifier whenSharesAmountNotZero() {
        _;
    }

    function test_ConvertToAssets()
        external
        whenTotalSupplyNotZero
        whenSharesAmountNotZero
    {
        uint256 freeFunds = multistrategyHarness.freeFunds();
        uint256 totalSupply = IERC20(address(multistrategyHarness)).totalSupply();

        // Assert share value is the amount of shares multiplied by freeFunds, divided by totalSupply
        uint256 ctualAssets = IERC4626(address(multistrategyHarness)).convertToAssets(shares);
        uint256 expectedAssets = Math.mulDiv(shares, freeFunds + 1, totalSupply + 1, Math.Rounding.Floor);
        assertEq(ctualAssets, expectedAssets, "convertToAssets");
    }
}