// SPDX-License-Identifier: MIT
pragma solidity^0.8.20;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { ICurveLPBase } from "interfaces/infra/multistrategy/adapters/ICurveLPBase.sol";
import { ICurveLiquidityPool } from "interfaces/curve/ICurveLiquidityPool.sol";
import { StrategyAdapterHarvestable } from "src/abstracts/StrategyAdapterHarvestable.sol";
import { CurveStableNgSDAdapter } from "src/infra/multistrategy/adapters/CurveStableNgSDAdapter.sol";
import { AssetsArbitrum, ProtocolArbitrum, UtilitiesArbitrum } from "@addressbook/AddressBook.sol";

contract DeployCurveStableNgSDAdapter is Script {
    /////////////////////////////////////////////////////////
    //                   ADAPTER CONFIG                    //
    /////////////////////////////////////////////////////////
    address constant MULTISTRATEGY = 0x3782bA74E32021dD2e2A7ADE5118E83440EE24E4; //FIXME:
    address constant ASSET = AssetsArbitrum.USDT;
    address constant GUARDIAN = 0xbd297B4f9991FD23f54e14111EE6190C4Fb9F7e1;
    string constant NAME = "Stake DAO Curve USDC/USDT LP";                            //FIXME:
    string constant ID = "CRVLP-SD";

    address curveLP = 0x49b720F1Aab26260BEAec93A7BeB5BF2925b2A8F;
    address sdVault = 0xa8D278db4ca48e7333901b24A83505BB078ecF86;
    address sdRewards = 0xAbf4368d120190B4F111C30C92cc9f8f6a6BE233;
    address[] rewards = [AssetsArbitrum.CRV];
    uint256 assetIndex = 1;

    function run() public {
        require(ICurveLiquidityPool(curveLP).coins(assetIndex) == ASSET, "WRONG ASSET INDEX!");

        StrategyAdapterHarvestable.HarvestAddresses memory harvestAddresses = StrategyAdapterHarvestable.HarvestAddresses({
            swapper: ProtocolArbitrum.GOAT_SWAPPER,
            wrappedGas: AssetsArbitrum.WETH
        });

        CurveStableNgSDAdapter.CurveSNGSDData memory curveData = CurveStableNgSDAdapter.CurveSNGSDData({
            curveLiquidityPool: curveLP,
            sdVault: sdVault,
            sdRewards: sdRewards,
            curveSlippageUtility: UtilitiesArbitrum.CURVE_STABLENG_SLIPPAGE_UTILITY,
            assetIndex: assetIndex
        });

        /////////////////////////////////////////////////////////
        //                 ADAPTER DEPLOYMENT                  //
        /////////////////////////////////////////////////////////

        vm.startBroadcast();

        CurveStableNgSDAdapter adapter = new CurveStableNgSDAdapter(MULTISTRATEGY, ASSET, harvestAddresses, curveData, NAME, ID);

        adapter.setSlippageLimit(1);                    // 0.01% Slippage permitted
        adapter.setCurveSlippageLimit(0.0001 ether);    // 0.01% Slippage permitted
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