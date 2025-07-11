// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {StargateAdapterNative} from "src/infra/multistrategy/adapters/StargateAdapterNative.sol";
import {StrategyAdapterHarvestable} from "src/abstracts/StrategyAdapterHarvestable.sol";
import { AssetsArbitrum, ProtocolArbitrum, VaultsArbitrum } from "@addressbook/AddressBook.sol";

contract DeployStargateAdapterNative is Script {
    /////////////////////////////////////////////////////////
    //                  HARVESTABLE CONFIG                 //
    /////////////////////////////////////////////////////////

    address swapper = ProtocolArbitrum.GOAT_SWAPPER;
    address weth = AssetsArbitrum.WETH;

    address[] rewards = [0x6694340fc020c5E6B96567843da2df01b2CE1eb6]; //STG

    /////////////////////////////////////////////////////////
    //                   ADAPTER CONFIG                    //
    /////////////////////////////////////////////////////////

    address stargateRouter = 0xA45B5130f36CDcA45667738e2a258AB09f4A5f7F;
    address stargateChef = 0x3da4f8E456AC648c489c286B99Ca37B666be7C4C;

    address constant MULTISTRATEGY = VaultsArbitrum.ycETH; //FIXME:
    address constant ASSET = AssetsArbitrum.WETH;
    address constant GUARDIAN = 0xbd297B4f9991FD23f54e14111EE6190C4Fb9F7e1;
    string constant NAME = "Stargate WETH"; //FIXME:
    string constant ID = "STARGATE";

    StrategyAdapterHarvestable.HarvestAddresses harvestAddresses =
        StrategyAdapterHarvestable.HarvestAddresses({
            swapper: swapper,
            wrappedGas: weth
        });

    StargateAdapterNative.StargateAddresses stargateAddresses =
        StargateAdapterNative.StargateAddresses({
            router: stargateRouter,
            chef: stargateChef
        });

    function run() public {
        /////////////////////////////////////////////////////////
        //                 ADAPTER DEPLOYMENT                  //
        /////////////////////////////////////////////////////////

        vm.startBroadcast();

        StargateAdapterNative adapter = new StargateAdapterNative(
            MULTISTRATEGY,
            ASSET,
            harvestAddresses,
            stargateAddresses,
            NAME,
            ID
        );

        for (uint i = 0; i < rewards.length; ++i) {
            adapter.addReward(rewards[i]);
        }

        adapter.enableGuardian(GUARDIAN);
        adapter.transferOwnership(ProtocolArbitrum.MULTI_MANAGER);

        vm.stopBroadcast();

        console.log("Stargate Adapter:", address(adapter));
    }
}
