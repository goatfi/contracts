// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.20 <0.9.0;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC4626, Multistrategy_Integration_Shared_Test } from "../../../shared/Multistrategy.t.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

contract ConvertToShares_Integration_Concrete_Test is Multistrategy_Integration_Shared_Test {
    uint256 assets = 1000 ether;

    function test_ConvertToShares_ZeroAmount() external {
        //Assert that shares for assets is zero when the assets of shares is zero
        uint256 actualShares = IERC4626(address(multistrategy)).convertToShares(0);
        uint256 expectedShares = 0;
        assertEq(actualShares, expectedShares, "convertToShares");
    }

    modifier whenAssetsNotZero() {
        _;
    }

    function test_ConvertToShares_ZeroTotalSupply() 
        external 
        whenAssetsNotZero
    {
        //Assert that shares for assets is zero when the assets of shares is zero
        uint256 actualShares = IERC4626(address(multistrategy)).convertToShares(assets);
        uint256 expectedShares = assets;
        assertEq(actualShares, expectedShares, "convertToShares");
    }

    modifier whenTotalSupplyNotZero() {
        triggerUserDeposit(users.bob, 1000 ether);
        _;
    }

    function test_ConvertToShares()
        external
        whenAssetsNotZero
        whenTotalSupplyNotZero
    {
        uint256 freeFunds = IERC4626(address(multistrategy)).totalAssets();
        uint256 totalSupply = IERC20(address(multistrategy)).totalSupply();

        //Assert that shares is the assets multiplied by totalSupply and divided by freeFunds
        uint256 actualShares = IERC4626(address(multistrategy)).convertToShares(assets);
        uint256 expectedShares = Math.mulDiv(assets, totalSupply + 1, freeFunds + 1, Math.Rounding.Floor);
        assertEq(actualShares, expectedShares, "convertToShares");
    }
}