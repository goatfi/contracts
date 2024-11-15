// SPDX-License-Identifier: MIT
pragma solidity^0.8.20;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { SiloAdapter } from "src/infra/multistrategy/adapters/SiloAdapter.sol";
import { StrategyAdapterHarvestable } from "src/abstracts/StrategyAdapterHarvestable.sol";
import { AssetsArbitrum } from "@addressbook/AssetsArbitrum.sol";
import { ProtocolArbitrum } from "@addressbook/ProtocolArbitrum.sol";

contract DeploySiloAdapter is Script {
    /////////////////////////////////////////////////////////
    //                    VAULT CONFIG                     //
    /////////////////////////////////////////////////////////
    address collateral = 0x713fc13CaAB628F116Bc34961f22a6B44aD27668;    //FIXME:
    address silo = 0xA8897b4552c075e884BDB8e7b704eB10DB29BF0D;          //FIXME:
    address siloLens = 0xBDb843c7a7e48Dc543424474d7Aa63b61B5D9536;
    address siloRewards = 0xbDBBf747402653A5aD6F6B8c49F2e8dCeC37fAcF;
    address merklDistributor = 0x3Ef3D8bA38EBe18DB133cEc108f4D14CE00Dd9Ae;
    address merklOperator = 0x1017417B0EE0a96Ee7230e534A83d35d28613B78;

    uint256 constant INITIAL_DEPOSIT = 1 * 1e6;

    address[] rewards = [AssetsArbitrum.SILO, 0x12275DCB9048680c4Be40942eA4D92c74C63b844];

    address swapper = ProtocolArbitrum.GOAT_SWAPPER;

    /////////////////////////////////////////////////////////
    //                   ADAPTER CONFIG                    //
    /////////////////////////////////////////////////////////
    address constant MULTISTRATEGY = 0x8a1eF3066553275829d1c0F64EE8D5871D5ce9d3; //FIXME:
    address constant ASSET = AssetsArbitrum.USDCe;
    address constant GUARDIAN = 0xbd297B4f9991FD23f54e14111EE6190C4Fb9F7e1;
    address constant TESTING_CUSTODIAN = 0x75cb5d555933fe86E0ac8975A623aCb5CEC13E28;
    string constant NAME = "Silo USDC.e WBTC Market";                            //FIXME:
    string constant ID = "SILO";

    SiloAdapter.SiloAddresses siloAddresses = SiloAdapter.SiloAddresses({
        silo: silo,
        collateral: collateral,
        siloLens: siloLens,
        siloRewards: siloRewards,
        merklDistributor: merklDistributor
    });

    StrategyAdapterHarvestable.HarvestAddresses harvestAddresses = StrategyAdapterHarvestable.HarvestAddresses({
        swapper: swapper,
        weth: AssetsArbitrum.WETH
    });

    function run() public {

        vm.startBroadcast();

        if(IERC20(ASSET).balanceOf(msg.sender) < INITIAL_DEPOSIT) {
            console.log("\u001b[1;31m NOT ENOUGH ASSETS FOR INITIAL DEPOSIT \u001b[0m");
            return;
        }

        /////////////////////////////////////////////////////////
        //                 ADAPTER DEPLOYMENT                  //
        /////////////////////////////////////////////////////////

        SiloAdapter adapter = new SiloAdapter(MULTISTRATEGY, ASSET, harvestAddresses, siloAddresses, NAME, ID);

        for(uint i = 0; i < rewards.length; ++i) {
            adapter.addReward(rewards[i]);
        }

        adapter.enableGuardian(GUARDIAN);
        adapter.toggleMerklOperator(merklOperator);
        adapter.transferOwnership(TESTING_CUSTODIAN);

        vm.stopBroadcast();

        console.log("Silo Adapter:", address(adapter));
    } 
}