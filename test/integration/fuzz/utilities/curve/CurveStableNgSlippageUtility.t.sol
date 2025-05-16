// SPDX-License-Identifier: GNU AGPLv3

pragma solidity 0.8.27;

import { Test } from "forge-std/Test.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { CurveStableNgSlippageUtility } from "src/infra/utilities/curve/CurveStableNgSlippageUtility.sol";
import { ICurveLiquidityPool } from "interfaces/curve/ICurveLiquidityPool.sol";

contract CurveStableNgSlippageUtility_Fuzz_Test is Test {
    using Math for uint256;
    
    CurveStableNgSlippageUtility curveSlippageUtility;
    address curveLp = 0x49b720F1Aab26260BEAec93A7BeB5BF2925b2A8F;
    uint256 N_COINS;

    function setUp() public {
        vm.createSelectFork(vm.envString("ARBITRUM_RPC_URL"));
        curveSlippageUtility = new CurveStableNgSlippageUtility();
        N_COINS = ICurveLiquidityPool(curveLp).N_COINS();
    }

    function testFuzz_GetDepositSlippage(uint256 _assetIndex, uint256 _amount) public view {
        _assetIndex = bound(_assetIndex, 0, N_COINS -1);
        address asset = ICurveLiquidityPool(curveLp).coins(_assetIndex);
        _amount = bound(_amount, 10, IERC20(asset).totalSupply() / 10);
        (uint256 slippage, ) = curveSlippageUtility.getDepositSlippage(curveLp, _assetIndex, _amount);

        assertLt(slippage, 1 ether);
    }

    function testFuzz_GetWithdrawSlippage(uint256 _assetIndex, uint256 _amount) public view {
        _assetIndex = bound(_assetIndex, 0, N_COINS -1);
        address asset = ICurveLiquidityPool(curveLp).coins(_assetIndex);
        _amount = bound(_amount, 2, IERC20(asset).balanceOf(curveLp).mulDiv(0.9995 ether, 1 ether));

        (uint256 slippage, ) = curveSlippageUtility.getWithdrawSlippage(curveLp, _assetIndex, _amount);

        assertLt(slippage, 1 ether);
    }
}