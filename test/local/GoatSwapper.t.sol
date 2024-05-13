// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import "forge-std/Test.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IGoatSwapper } from "interfaces/infra/IGoatSwapper.sol";
import { ProtocolArbitrum } from "@addressbook/ProtocolArbitrum.sol";
import { AssetsArbitrum } from "@addressbook/AssetsArbitrum.sol";
import { ISwapRouter } from "@uniswapV3-periphery/interfaces/ISwapRouter.sol";
import { ApproxParams, TokenInput, SwapData, SwapType } from "interfaces/pendle/IPendleRouter.sol";
import { ICurveRouter } from "interfaces/curve/ICurveRouter.sol";

contract GoatSwapperTest is Test {
    /*//////////////////////////////////////////////////////////////////////////
                                   VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    address bob = makeAddr("bob");

    address fromToken = AssetsArbitrum.CRVUSD;
    address toToken = 0x49014A8eB1585cBee6A7a9A50C3b81017BF6Cc4d;

    /*//////////////////////////////////////////////////////////////////////////
                                   TEST CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/

    IGoatSwapper swapper;

    /*//////////////////////////////////////////////////////////////////////////
                                  SET-UP FUNCTION
    //////////////////////////////////////////////////////////////////////////*/

    function setUp() public virtual {
        vm.createSelectFork(vm.envString("ARBITRUM_RPC_URL"));
        swapper = IGoatSwapper(ProtocolArbitrum.GOAT_SWAPPER);

        _setSwapInfo();
    }

    function test_Swap() public {
        deal(bob, 1 ether);
        deal(fromToken, bob, 100 ether);

        vm.startPrank(bob);
        uint256 fromBalance = IERC20(fromToken).balanceOf(bob);
        IERC20(fromToken).approve(address(swapper), fromBalance);

        swapper.swap(fromToken, toToken, fromBalance);

        vm.stopPrank();

        assertEq(IERC20(fromToken).balanceOf(bob), 0);
        assertGt(IERC20(toToken).balanceOf(bob), 0);

        console.log(IERC20(toToken).balanceOf(bob));
    }

    function _setSwapInfo() internal {
        vm.startPrank(0xbd297B4f9991FD23f54e14111EE6190C4Fb9F7e1);

        (address router, bytes memory data, uint256 amountIndex) = _generateCurveLendDepositData();
        IGoatSwapper.SwapInfo memory swapInfo = IGoatSwapper.SwapInfo(router, data, amountIndex);

        console.log(router);
        console.logBytes(data);
        console.log(amountIndex);

        swapper.setSwapInfo(fromToken, toToken, swapInfo);
        vm.stopPrank();
    }

    function _generateUniSwapData() internal pure returns (address router, bytes memory data, uint256 amountIndex) {
        router = 0xE592427A0AEce92De3Edee1F18E0157C05861564;
        amountIndex = 132;
        bytes memory path = bytes.concat(bytes20(AssetsArbitrum.WETH), bytes3(uint24(500)), bytes20(AssetsArbitrum.USDCe));

        ISwapRouter.ExactInputParams memory params =
            ISwapRouter.ExactInputParams({ path: path, recipient: ProtocolArbitrum.GOAT_SWAPPER, deadline: type(uint256).max, amountIn: 4_198_024_319_081_571, amountOutMinimum: 0 });

        data = abi.encodeWithSignature("exactInput((bytes,address,uint256,uint256,uint256))", params);
    }

    function _generateCamelotData() internal pure returns (address router, bytes memory data, uint256 amountIndex) {
        router = 0x1F721E2E82F6676FCE4eA07A5958cF098D339e18;
        amountIndex = 132;
        uint256 amountIn = 0;
        uint256 amountOutMin = 0;
        address[] memory path = new address[](2);
        path[0] = 0xBfbCFe8873fE28Dfa25f1099282b088D52bbAD9C;
        path[1] = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
        address to = ProtocolArbitrum.GOAT_SWAPPER;
        address referrer = address(0);
        uint256 deadline = type(uint256).max;

        data = abi.encodeWithSignature("swapExactTokensForTokensSupportingFeeOnTransferTokens(uint256,uint256,address[],address,address,uint256)", amountIn, amountOutMin, path, to, referrer, deadline);
    }

    function _generateCamelotExactInputData() internal pure returns (address router, bytes memory data, uint256 amountIndex) {
        router = 0x1F721E2E82F6676FCE4eA07A5958cF098D339e18;
        amountIndex = 132;
        bytes memory path = bytes.concat(bytes20(AssetsArbitrum.WETH), bytes20(0x4186BFC76E2E237523CBC30FD220FE055156b41F));

        ISwapRouter.ExactInputParams memory params = ISwapRouter.ExactInputParams({
            path: path,
            recipient: ProtocolArbitrum.GOAT_SWAPPER,
            deadline: type(uint256).max,
            amountIn: 4_198_024_319_081_571, //Random
            amountOutMinimum: 0
        });

        data = abi.encodeWithSignature("exactInput((bytes,address,uint256,uint256,uint256))", params);
    }

    function _generatePendleDepositData() internal pure returns (address router, bytes memory data, uint256 amountIndex) {
        router = 0x0000000001E4ef00d069e71d6bA041b0A16F7eA0;
        amountIndex = 324;
        address receiver = ProtocolArbitrum.GOAT_SWAPPER;
        address market = 0x5E03C94Fc5Fb2E21882000A96Df0b63d2c4312e2;
        uint256 minLpOut = 0;
        ApproxParams memory guessPtReceivedFromSy = ApproxParams({ guessMin: 0, guessMax: type(uint256).max, guessOffchain: 0, maxIteration: 256, eps: 1_000_000_000_000_000 });
        TokenInput memory input = TokenInput({
            tokenIn: AssetsArbitrum.WETH,
            netTokenIn: 0,
            tokenMintSy: AssetsArbitrum.WETH,
            bulk: address(0),
            pendleSwap: address(0),
            swapData: SwapData({ swapType: SwapType.NONE, extRouter: address(0), extCalldata: new bytes(0), needScale: false })
        });

        data = abi.encodeWithSignature(
            "addLiquiditySingleToken(address,address,uint256,(uint256,uint256,uint256,uint256,uint256),(address,uint256,address,address,address,(uint8,address,bytes,bool)))",
            receiver,
            market,
            minLpOut,
            guessPtReceivedFromSy,
            input
        );
    }

    function _generateCurveData() internal pure returns (address router, bytes memory data, uint256 amountIndex) {
        router = 0xF0d4c12A5768D806021F80a262B4d39d26C58b8D;
        amountIndex = 1156;

        address[11] memory _route;
        uint256[5][5] memory _swapParams;
        uint256 _amount = 4_198_024_319_081_571; //Random
        uint256 _expected = 0;

        _route = [
            0x82aF49447D8a07e3bd95BD0d56f35241523fBab1,
            0xF7Fed8Ae0c5B78c19Aadd68b700696933B0Cefd9,
            0xF7Fed8Ae0c5B78c19Aadd68b700696933B0Cefd9,
            0x0000000000000000000000000000000000000000,
            0x0000000000000000000000000000000000000000,
            0x0000000000000000000000000000000000000000,
            0x0000000000000000000000000000000000000000,
            0x0000000000000000000000000000000000000000,
            0x0000000000000000000000000000000000000000,
            0x0000000000000000000000000000000000000000,
            0x0000000000000000000000000000000000000000
        ];
        _swapParams = [[uint256(2), 0, 4, 3, 3], [uint256(0), 0, 0, 0, 0], [uint256(0), 0, 0, 0, 0], [uint256(0), 0, 0, 0, 0], [uint256(0), 0, 0, 0, 0]];

        data = abi.encodeWithSignature("exchange(address[11],uint256[5][5],uint256,uint256)", _route, _swapParams, _amount, _expected);
    }

    function _generateCurveDepositData(address _toToken) internal pure returns (address router, bytes memory data, uint256 amountIndex) {
        router = _toToken;
        amountIndex = 100;

        uint256 _amount = 4_198_024_319_081_571; //Random
        uint256 _min_mint_amount = 0;

        //Need to check which position (0 or 1) we deposit. Depends on the LP token0 & token1 and depositToken on the strategy.
        uint256[] memory _amounts = new uint256[](2);
        _amounts[0] = _amount;
        _amounts[1] = 0;

        data = abi.encodeWithSignature("add_liquidity(uint256[],uint256)", _amounts, _min_mint_amount);
    }

    function _generateCurveLendDepositData() internal pure returns (address router, bytes memory data, uint256 amountIndex) {
        router = 0x49014A8eB1585cBee6A7a9A50C3b81017BF6Cc4d; //crvUSD Vault
        amountIndex = 4;

        uint256 _amount = 4_198_024_319_081_571; //Random

        data = abi.encodeWithSignature("deposit(uint256)", _amount);
    }

    function _generateVirtuswapData(address _fromToken, address _toToken) internal pure returns (address router, bytes memory data, uint256 amountIndex) {
        router = 0xB455da5a32E7E374dB6d1eDfdb86C167DD983f40;
        amountIndex = 36;

        address[] memory _path = new address[](2);
        _path[0] = _fromToken;
        _path[1] = _toToken;
        uint256 _amountIn = 4_198_024_319_081_571;
        uint256 _minAmountOut = 0;
        address _to = ProtocolArbitrum.GOAT_SWAPPER;
        uint256 _deadline = type(uint256).max;

        data = abi.encodeWithSignature("swapExactTokensForTokens(address[],uint256,uint256,address,uint256)", _path, _amountIn, _minAmountOut, _to, _deadline);
    }

    function _generateVirtuswapAddLiquidityOneSided() internal pure returns (address router, bytes memory data, uint256 amountIndex) {
        router = 0x74c2D8B6977EEe5220d118E0d6a0746ac137f06E; //OneSidedLiquidityHelper
        amountIndex = 68;
        address _tokenA = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1; //WETH
        address _tokenB = 0x5979D7b546E38E414F7E9822514be443A4800529; //wstETH <-- Change this
        uint256 _amountIn = 4_198_024_319_081_571;

        data = abi.encodeWithSignature("addLiquidityOneSided(address,address,uint256)", _tokenA, _tokenB, _amountIn);
    }
}
