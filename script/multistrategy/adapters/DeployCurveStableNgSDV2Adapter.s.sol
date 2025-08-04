// SPDX-License-Identifier: MIT
pragma solidity^0.8.20;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { ICurveLPBase } from "interfaces/infra/multistrategy/adapters/ICurveLPBase.sol";
import { ICurveLiquidityPool } from "interfaces/curve/ICurveLiquidityPool.sol";
import { StrategyAdapterHarvestable } from "src/abstracts/StrategyAdapterHarvestable.sol";
import { CurveStableNgSDV2Adapter } from "src/infra/multistrategy/adapters/CurveStableNgSDV2Adapter.sol";
import { AssetsArbitrum, ProtocolArbitrum, UtilitiesArbitrum, VaultsArbitrum } from "@addressbook/AddressBook.sol";

contract DeployCurveStableNgSDV2Adapter is Script {
    /////////////////////////////////////////////////////////
    //                   ADAPTER CONFIG                    //
    /////////////////////////////////////////////////////////
    address constant MULTISTRATEGY = VaultsArbitrum.ycUSDT;
    address constant ASSET = AssetsArbitrum.USDT;
    address constant GUARDIAN = 0xbd297B4f9991FD23f54e14111EE6190C4Fb9F7e1;
    string constant NAME = "Stake DAO Curve USDC/USDT LP";
    string constant ID = "CRV-SDV2-LP";

    address curveLP = 0x49b720F1Aab26260BEAec93A7BeB5BF2925b2A8F;
    address sdVault = 0x5E162b4AC251599a218B0C37b4854E33a54fFCa7;
    address[] rewards = [AssetsArbitrum.CRV];
    uint256 assetIndex = 1;

    function run() public {
        require(ICurveLiquidityPool(curveLP).coins(assetIndex) == ASSET, "WRONG ASSET INDEX!");

        StrategyAdapterHarvestable.HarvestAddresses memory harvestAddresses = StrategyAdapterHarvestable.HarvestAddresses({
            swapper: ProtocolArbitrum.GOAT_SWAPPER,
            wrappedGas: AssetsArbitrum.WETH
        });

        CurveStableNgSDV2Adapter.CurveSNGSDV2Data memory curveData = CurveStableNgSDV2Adapter.CurveSNGSDV2Data({
            curveLiquidityPool: curveLP,
            sdVault: sdVault,
            curveSlippageUtility: UtilitiesArbitrum.CURVE_STABLENG_SLIPPAGE_UTILITY,
            assetIndex: assetIndex
        });

        /////////////////////////////////////////////////////////
        //                 ADAPTER DEPLOYMENT                  //
        /////////////////////////////////////////////////////////

        vm.startBroadcast();

        CurveStableNgSDV2Adapter adapter = new CurveStableNgSDV2Adapter(MULTISTRATEGY, ASSET, harvestAddresses, curveData, NAME, ID);

        adapter.setSlippageLimit(4);                    // 0.05% Slippage permitted
        adapter.setCurveSlippageLimit(0.0004 ether);    // 0.05% Slippage permitted
        adapter.setWithdrawBufferPPM(2);                // 2 parts per million buffer on withdraws
        for(uint i = 0; i < rewards.length; ++i) {
            adapter.addReward(rewards[i]);
        }

        adapter.enableGuardian(GUARDIAN);
        adapter.transferOwnership(ProtocolArbitrum.MULTI_MANAGER);

        vm.stopBroadcast();

        console.log("Curve LP Adapter:", address(adapter));

        //////////////////////////////////////////////////////////////////////////
        //                 SET STRATEGY MIN DEBT DELTA ON SAFE                  //
        //////////////////////////////////////////////////////////////////////////
    }
}