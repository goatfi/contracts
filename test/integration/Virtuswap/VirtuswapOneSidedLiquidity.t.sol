// SPDX-License-Identifier: MIT

pragma solidity^0.8.20;

import "forge-std/Test.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { VirtuswapOneSidedLiquidity } from "src/infra/strategies/virtuswap/VirtuswapOneSidedLiquidity.sol";
import { IvPairFactory } from "interfaces/virtuswap/IvPairFactory.sol";
import { IGoatSwapper } from "interfaces/infra/IGoatSwapper.sol";
import { AssetsArbitrum } from "@addressbook/AssetsArbitrum.sol";
import { ProtocolArbitrum } from "@addressbook/ProtocolArbitrum.sol";

contract VirtuswapOneSidedLiquidityTest is Test {
    /*//////////////////////////////////////////////////////////////////////////
                                   VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    address private constant FACTORY = 0x389DB0B69e74A816f1367aC081FdF24B5C7C2433;
    address private constant ROUTER = 0xB455da5a32E7E374dB6d1eDfdb86C167DD983f40;
    address weth = AssetsArbitrum.WETH;
    address usdce = AssetsArbitrum.USDCe;
    address vrsw = 0xd1E094CabC5aCB9D3b0599C3F76f2D01fF8d3563;
    address want = 0x8431aAaa1bB7BD11d4740F19a0306e00b7eDB817;

    /*//////////////////////////////////////////////////////////////////////////
                                   TEST CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/

    VirtuswapOneSidedLiquidity vswapLiquidityHelper;
    IGoatSwapper swapper;

    error InvalidCaller(address swapper, address caller);
    error InsufficientAmount(uint256 amount);

    /*//////////////////////////////////////////////////////////////////////////
                                  SET-UP FUNCTION
    //////////////////////////////////////////////////////////////////////////*/

    function setUp() public virtual {
        vm.createSelectFork(vm.envString("ARBITRUM_RPC_URL"));
        swapper = IGoatSwapper(ProtocolArbitrum.GOAT_SWAPPER);
        vswapLiquidityHelper = new VirtuswapOneSidedLiquidity(ProtocolArbitrum.GOAT_SWAPPER, FACTORY, ROUTER);
        _addNativeToWantSwapInfo();
    }

    function test_addLiquidityOneSided() public {
        deal(weth, address(swapper), 1 ether);
        vm.startPrank(address(swapper));
        uint256 amountA = IERC20(weth).balanceOf(address(swapper));
        IERC20(weth).approve(address(vswapLiquidityHelper), amountA);

        vswapLiquidityHelper.addLiquidityOneSided(weth, vrsw, amountA);
        vm.stopPrank();

        assertEq(IERC20(weth).balanceOf(address(swapper)), 0);
        assertGt(IERC20(IvPairFactory(FACTORY).pairs(weth, vrsw)).balanceOf(address(swapper)), 0);
    }

    function test_addLiquidityOneSided_LowDecimalToken() public {
        deal(usdce, address(swapper), 100e6);
        vm.startPrank(address(swapper));
        uint256 amountA = IERC20(usdce).balanceOf(address(swapper));
        IERC20(usdce).approve(address(vswapLiquidityHelper), amountA);

        vswapLiquidityHelper.addLiquidityOneSided(usdce, vrsw, amountA);

        vm.stopPrank();

        assertEq(IERC20(usdce).balanceOf(address(swapper)), 0);
        assertGt(IERC20(IvPairFactory(FACTORY).pairs(usdce, vrsw)).balanceOf(address(swapper)), 0);
    }

    function test_fromRewardToWant() public {
        uint256 amount = 1000 ether;
        deal(vrsw, address(this), amount);

        IERC20(vrsw).approve(address(swapper), amount);
        IERC20(weth).approve(address(swapper), type(uint256).max);

        swapper.swap(vrsw, weth, amount);
        swapper.swap(weth, want, IERC20(weth).balanceOf(address(this)));

        assertEq(IERC20(vrsw).balanceOf(address(this)), 0);
        assertGt(IERC20(want).balanceOf(address(this)), 0);
    }

    function test_revertWhen_notCalledFromSwapper() public {
        deal(weth, address(swapper), 1 ether);

        uint256 amountA = IERC20(weth).balanceOf(address(swapper));
        IERC20(weth).approve(address(vswapLiquidityHelper), amountA);

        vm.expectRevert(abi.encodeWithSelector(InvalidCaller.selector, ProtocolArbitrum.GOAT_SWAPPER, address(this)));
        vswapLiquidityHelper.addLiquidityOneSided(weth, vrsw, amountA);
    }

    function test_revertWhen_InsufficientLiquidityAmount() public {
        deal(weth, address(swapper), 1 ether);
        vm.startPrank(address(swapper));
        uint256 amountA = 0;
        IERC20(weth).approve(address(vswapLiquidityHelper), amountA);

        vm.expectRevert(abi.encodeWithSelector(InsufficientAmount.selector, amountA));
        vswapLiquidityHelper.addLiquidityOneSided(weth, vrsw, amountA);
        
        vm.stopPrank();
    }

    function _addNativeToWantSwapInfo() internal {
        IGoatSwapper.SwapInfo memory swapInfo = IGoatSwapper.SwapInfo({
            router: address(vswapLiquidityHelper),
            data: abi.encodeWithSignature("addLiquidityOneSided(address,address,uint256)", weth, vrsw, 4198024319081571),
            amountIndex: 68
        });
        vm.prank(0xbd297B4f9991FD23f54e14111EE6190C4Fb9F7e1);
        swapper.setSwapInfo(weth, want, swapInfo);
    }
}