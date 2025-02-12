// SPDX-License-Identifier: MIT
pragma solidity^0.8.20;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { SiloV2Adapter } from "src/infra/multistrategy/adapters/SiloV2Adapter.sol";
import { StrategyAdapterHarvestable } from "src/abstracts/StrategyAdapterHarvestable.sol";
import { AssetsSonic, ProtocolSonic } from "@addressbook/AddressBook.sol";

contract DeploySiloV2Adapter is Script {
    //address[] rewards = []; //FIXME: Add rewards if any

    address vault = 0x4E216C15697C1392fE59e1014B009505E05810Df;
    address incentivesController = 0x0dd368Cd6D8869F2b21BA3Cb4fd7bA107a2e3752;

    /////////////////////////////////////////////////////////
    //                   ADAPTER CONFIG                    //
    /////////////////////////////////////////////////////////
    address constant MULTISTRATEGY = 0x901e3059Bf118AbC74d917440F0C08FC78eC0Aa6; //FIXME:
    address constant ASSET = AssetsSonic.USDCe;
    address constant GUARDIAN = 0xbd297B4f9991FD23f54e14111EE6190C4Fb9F7e1;
    address constant TESTING_CUSTODIAN = 0x75cb5d555933fe86E0ac8975A623aCb5CEC13E28;
    string constant NAME = "Silo S/USDC.e ID-8";                            //FIXME:
    string constant ID = "SILO-V2";

    StrategyAdapterHarvestable.HarvestAddresses harvestAddresses = StrategyAdapterHarvestable.HarvestAddresses({
        swapper: ProtocolSonic.GOAT_SWAPPER,
        wrappedGas: AssetsSonic.WS
    });

    function run() public {

        /////////////////////////////////////////////////////////
        //                 ADAPTER DEPLOYMENT                  //
        /////////////////////////////////////////////////////////

        vm.startBroadcast();

        SiloV2Adapter adapter = new SiloV2Adapter(MULTISTRATEGY, ASSET, vault, incentivesController, harvestAddresses, NAME, ID);

        /*for(uint i = 0; i < rewards.length; ++i) {
            adapter.addReward(rewards[i]);
        }*/

        adapter.enableGuardian(GUARDIAN);
        adapter.transferOwnership(TESTING_CUSTODIAN);

        vm.stopBroadcast();

        console.log("Silo Adapter:", address(adapter));
    }
}