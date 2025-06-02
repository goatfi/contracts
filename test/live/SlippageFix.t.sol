// SPDX-License-Identifier: MIT
pragma solidity^0.8.20;

import { Test } from "forge-std/Test.sol";
import { console } from "forge-std/console.sol";
import { Multistrategy } from "src/infra/multistrategy/Multistrategy.sol";
import { StrategyAdapter } from "src/abstracts/StrategyAdapter.sol";
import { StrategyAdapterHarvestable } from "src/abstracts/StrategyAdapterHarvestable.sol";
import { CurveStableNgSDAdapter } from "src/infra/multistrategy/adapters/CurveStableNgSDAdapter.sol";
import { ITimelock } from "interfaces/infra/ITimelock.sol";
import { AssetsArbitrum, ProtocolArbitrum, UtilitiesArbitrum } from "@addressbook/AddressBook.sol";

contract SlippageFix is Test {
    Multistrategy multi = Multistrategy(0x0df2e3a0b5997AdC69f8768E495FD98A4D00F134); 
    StrategyAdapter revertAdapter = StrategyAdapter(0xE11CD37AA115E2BAfc2e7960DbF612Dfbf656e5F);
    CurveStableNgSDAdapter lpAdapter;
    ITimelock timelock = ITimelock(ProtocolArbitrum.TIMELOCK);

    function setUp() public {
        vm.createSelectFork(vm.envString("ARBITRUM_RPC_URL"), 341384965 - 24 hours);

        createAdapter();

        vm.prank(ProtocolArbitrum.TREASURY); timelock.schedule(address(multi), 0, abi.encodeWithSelector(multi.addStrategy.selector, lpAdapter, 0, 1e6, type(uint256).max), 0, 0, 43200);
        vm.warp(block.timestamp + 24 hours);
        vm.prank(ProtocolArbitrum.TREASURY); timelock.execute(address(multi), 0, abi.encodeWithSelector(multi.addStrategy.selector, lpAdapter, 0, 1e6, type(uint256).max), 0, 0);
    }

    function createAdapter() public {
        CurveStableNgSDAdapter.CurveSNGSDData memory curveData = CurveStableNgSDAdapter.CurveSNGSDData({
            curveLiquidityPool: 0x49b720F1Aab26260BEAec93A7BeB5BF2925b2A8F,
            sdVault: 0xa8D278db4ca48e7333901b24A83505BB078ecF86,
            sdRewards: 0xAbf4368d120190B4F111C30C92cc9f8f6a6BE233,
            curveSlippageUtility: UtilitiesArbitrum.CURVE_STABLENG_SLIPPAGE_UTILITY,
            assetIndex: 0
        });

        StrategyAdapterHarvestable.HarvestAddresses memory harvestData = StrategyAdapterHarvestable.HarvestAddresses({
            swapper: ProtocolArbitrum.GOAT_SWAPPER,
            wrappedGas: AssetsArbitrum.WETH
        });

        lpAdapter = new CurveStableNgSDAdapter(address(multi), multi.asset(), harvestData, curveData, "", "");
        lpAdapter.setSlippageLimit(3);
        lpAdapter.setCurveSlippageLimit(0.0003 ether);
        lpAdapter.setWithdrawBufferPPM(2);
        lpAdapter.addReward(AssetsArbitrum.CRV);
        lpAdapter.transferOwnership(ProtocolArbitrum.MULTI_MANAGER);
    }

    function test_slippageFix() public {
        assertEq(multi.getStrategyParameters(address(revertAdapter)).debtRatio, 10_000);

        vm.startPrank(ProtocolArbitrum.MULTI_MANAGER); 
            multi.setStrategyDebtRatio(address(revertAdapter), 9_000);
            multi.setStrategyDebtRatio(address(lpAdapter), 1_000);
            revertAdapter.sendReport(type(uint256).max);
            lpAdapter.requestCredit();
        vm.stopPrank();

        vm.warp(block.timestamp + 6 hours);

        vm.startPrank(ProtocolArbitrum.MULTI_MANAGER); 
            multi.setStrategyDebtRatio(address(lpAdapter), 0);
            multi.setStrategyDebtRatio(address(revertAdapter), 10_000);
            lpAdapter.sendReport(type(uint256).max);
            revertAdapter.requestCredit();
        vm.stopPrank();
    }
}