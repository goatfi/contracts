// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.20 <0.9.0;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import { IERC4626, Multistrategy_Integration_Shared_Test } from "../../../shared/Multistrategy.t.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

contract ConvertToShares_Integration_Concrete_Test is Multistrategy_Integration_Shared_Test {
    uint256 deposit = 1000;
    uint256 assets;
    uint8 decimals;

    function setUp() public virtual override {
        Multistrategy_Integration_Shared_Test.setUp();
        decimals = IERC20Metadata(IERC4626(address(multistrategy)).asset()).decimals();
        assets = deposit * 10 ** decimals;
    }

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
        uint256 expectedShares = deposit * 1e18;
        assertEq(actualShares, expectedShares, "convertToShares");
    }

    modifier whenTotalSupplyNotZero() {
        triggerUserDeposit(users.bob, assets);
        _;
    }

    function test_ConvertToShares()
        external
        whenAssetsNotZero
        whenTotalSupplyNotZero
    {
        uint256 decimalsOffset = uint256(18) - IERC20Metadata(IERC4626(address(multistrategy)).asset()).decimals();
        uint256 freeFunds = IERC4626(address(multistrategy)).totalAssets();
        uint256 totalSupply = IERC20(address(multistrategy)).totalSupply();

        //Assert that shares is the assets multiplied by totalSupply and divided by freeFunds
        uint256 actualShares = IERC4626(address(multistrategy)).convertToShares(assets);
        uint256 expectedShares = Math.mulDiv(assets, totalSupply + 10 ** decimalsOffset, freeFunds + 1, Math.Rounding.Floor);
        assertEq(actualShares, expectedShares, "convertToShares");
    }
}