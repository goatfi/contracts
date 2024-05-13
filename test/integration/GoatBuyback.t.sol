// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import "forge-std/Test.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { GoatUniswapV3Buyback } from "src/infra/GoatUniswapV3Buyback.sol";
import { AssetsArbitrum} from "@addressbook/AssetsArbitrum.sol";

contract GoatBuyback is Test {

    /*//////////////////////////////////////////////////////////////////////////
                                   VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    address weth = AssetsArbitrum.WETH;
    address goa = AssetsArbitrum.GOA;

    /*//////////////////////////////////////////////////////////////////////////
                                   TEST CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/

    GoatUniswapV3Buyback buyback;

    error InvalidCaller();
    error ZeroAddress();

    /*//////////////////////////////////////////////////////////////////////////
                                  SET-UP FUNCTION
    //////////////////////////////////////////////////////////////////////////*/

    function setUp() public virtual {
        vm.createSelectFork(vm.envString("ARBITRUM_RPC_URL"));
        buyback = new GoatUniswapV3Buyback(address(this));

        deal(weth, address(this), 1 ether);
    }

    function test_swapAmount() public {
        uint256 amountIn = IERC20(weth).balanceOf(address(this));
        IERC20(weth).approve(address(buyback), amountIn);
        uint256 amountOut = buyback.swap(weth, goa, amountIn);

        assertLt(IERC20(weth).balanceOf(address(this)), amountIn);
        assertGt(amountOut, 0);
    }

    function test_RevertWhen_InvalidCaller() public {
        address bob = makeAddr("bob");
        deal(weth, bob, 1 ether);

        vm.startPrank(bob);
        uint256 amountIn = IERC20(weth).balanceOf(bob);
        IERC20(weth).approve(address(buyback), amountIn);
        vm.expectRevert(InvalidCaller.selector);
        buyback.swap(weth, goa, amountIn);
        vm.stopPrank();
    }

    function test_RevertWhen_ZeroAddress() public {
        uint256 amountIn = IERC20(weth).balanceOf(address(this));
        IERC20(weth).approve(address(buyback), amountIn);
        vm.expectRevert(ZeroAddress.selector);
        buyback.swap(address(0), goa, amountIn);

        vm.expectRevert(ZeroAddress.selector);
        buyback.swap(weth, address(0), amountIn);
    }
}
