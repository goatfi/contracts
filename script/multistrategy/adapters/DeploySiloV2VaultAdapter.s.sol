// SPDX-License-Identifier: MIT
pragma solidity^0.8.20;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { SiloV2VaultAdapter } from "src/infra/multistrategy/adapters/SiloV2VaultAdapter.sol";
import { StrategyAdapterHarvestable } from "src/abstracts/StrategyAdapterHarvestable.sol";
import { AssetsSonic, ProtocolSonic, VaultsSonic } from "@addressbook/AddressBook.sol";

contract DeploySiloV2VaultAdapter is Script {
    address[] rewards = [AssetsSonic.WOS]; //FIXME: Add rewards if any

    address vault = 0xEAe86f9E60b156007d30b4Cd4eAae8f11008530C;
    address incentivesController = 0xF29baA0D47CB1449eD5C131CBbA600227e7A1D76;
    address idleMarket = 0xAd13aa7D8Cbfcc176260f298783Da9304Bee13A0;

    /////////////////////////////////////////////////////////
    //                   ADAPTER CONFIG                    //
    /////////////////////////////////////////////////////////
    address constant MULTISTRATEGY = VaultsSonic.ycS; //FIXME:
    address constant ASSET = AssetsSonic.WS;
    address constant GUARDIAN = 0xbd297B4f9991FD23f54e14111EE6190C4Fb9F7e1;
    string constant NAME = "Silo Yield Optimized Sonic";  //FIXME:
    string constant ID = "SILO-V2-VAULT";

    StrategyAdapterHarvestable.HarvestAddresses harvestAddresses = StrategyAdapterHarvestable.HarvestAddresses({
        swapper: ProtocolSonic.GOAT_SWAPPER,
        wrappedGas: AssetsSonic.WS
    });

    function run() public {

        /////////////////////////////////////////////////////////
        //                 ADAPTER DEPLOYMENT                  //
        /////////////////////////////////////////////////////////

        vm.startBroadcast();

        SiloV2VaultAdapter.SiloV2VaultAddresses memory siloV2Addresses = SiloV2VaultAdapter.SiloV2VaultAddresses({
            incentivesController: incentivesController,
            idleMarket: idleMarket
        });

        SiloV2VaultAdapter adapter = new SiloV2VaultAdapter(MULTISTRATEGY, ASSET, vault, siloV2Addresses, harvestAddresses, NAME, ID);

        for(uint i = 0; i < rewards.length; ++i) {
            adapter.addReward(rewards[i]);
        }

        adapter.enableGuardian(GUARDIAN);
        adapter.transferOwnership(ProtocolSonic.MULTI_MANAGER);

        vm.stopBroadcast();

        console.log("Silo V2 Vault Adapter:", address(adapter));
    }
}