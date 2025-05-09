// SPDX-License-Identifier: MIT
pragma solidity^0.8.20;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { SiloAdapter } from "src/infra/multistrategy/adapters/SiloAdapter.sol";
import { StrategyAdapterHarvestable } from "src/abstracts/StrategyAdapterHarvestable.sol";
import { AssetsArbitrum, ProtocolArbitrum } from "@addressbook/AddressBook.sol";
import { ISilo, ISiloRepository } from "interfaces/silo/ISilo.sol";

contract DeploySiloAdapter is Script {
    address marketAsset = AssetsArbitrum.ezETH; //FIXME:
    
    address siloRepository = 0x8658047e48CC09161f4152c79155Dac1d710Ff0a;
    address siloLens = 0xBDb843c7a7e48Dc543424474d7Aa63b61B5D9536;
    address siloRewards = 0xbDBBf747402653A5aD6F6B8c49F2e8dCeC37fAcF;
    address merklDistributor = 0x3Ef3D8bA38EBe18DB133cEc108f4D14CE00Dd9Ae;
    address merklOperator = 0x1017417B0EE0a96Ee7230e534A83d35d28613B78;

    address[] rewards = [AssetsArbitrum.SILO];

    /////////////////////////////////////////////////////////
    //                   ADAPTER CONFIG                    //
    /////////////////////////////////////////////////////////
    address constant MULTISTRATEGY = 0x8a1eF3066553275829d1c0F64EE8D5871D5ce9d3; //FIXME:
    address constant ASSET = AssetsArbitrum.USDCe;
    address constant GUARDIAN = 0xbd297B4f9991FD23f54e14111EE6190C4Fb9F7e1;
    string constant NAME = "Silo WETH ezETH Market";                            //FIXME:
    string constant ID = "SILO";

    StrategyAdapterHarvestable.HarvestAddresses harvestAddresses = StrategyAdapterHarvestable.HarvestAddresses({
        swapper: ProtocolArbitrum.GOAT_SWAPPER,
        wrappedGas: AssetsArbitrum.WETH
    });

    function run() public {

        /////////////////////////////////////////////////////////
        //                 ADAPTER DEPLOYMENT                  //
        /////////////////////////////////////////////////////////

        vm.startBroadcast();

        address silo = ISiloRepository(siloRepository).getSilo(marketAsset);
        address collateral = ISilo(silo).assetStorage(ASSET).collateralToken;
        SiloAdapter.SiloAddresses memory siloAddresses = SiloAdapter.SiloAddresses({
            silo: silo,
            collateral: collateral,
            siloLens: siloLens,
            siloRewards: siloRewards,
            merklDistributor: merklDistributor
        });

        SiloAdapter adapter = new SiloAdapter(MULTISTRATEGY, ASSET, harvestAddresses, siloAddresses, NAME, ID);

        for(uint i = 0; i < rewards.length; ++i) {
            adapter.addReward(rewards[i]);
        }

        adapter.enableGuardian(GUARDIAN);
        adapter.toggleMerklOperator(merklOperator);
        adapter.transferOwnership(ProtocolArbitrum.MULTI_MANAGER);

        vm.stopBroadcast();

        console.log("Silo Adapter:", address(adapter));
    } 
}