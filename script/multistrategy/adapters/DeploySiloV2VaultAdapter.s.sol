// SPDX-License-Identifier: MIT
pragma solidity^0.8.20;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import { ISiloV2Vault } from "interfaces/silo/ISiloV2Vault.sol";
import { ISiloV2IncetivesModule } from "interfaces/silo/ISiloV2IncetivesModule.sol";
import { SiloV2VaultAdapter } from "src/infra/multistrategy/adapters/SiloV2VaultAdapter.sol";
import { StrategyAdapterHarvestable } from "src/abstracts/StrategyAdapterHarvestable.sol";
import { Addressbook } from "@addressbook/AddressBook.sol";

/// @title Deploys a SiloV2 Curated Vault Adapter
contract DeploySiloV2VaultAdapter is Script {
    Addressbook addressbook = new Addressbook();

    function run(
        address multistrategy,
        string memory name,
        address silo_vault,
        address idle_market,
        address[] memory rewards
    ) public {

        address asset = IERC4626(multistrategy).asset();
        address manager = addressbook.getManager(block.chainid);
        address guardian = addressbook.getGuardian(block.chainid);
        address[] memory notificactionReceivers = ISiloV2IncetivesModule(ISiloV2Vault(silo_vault).INCENTIVES_MODULE()).getNotificationReceivers();

        StrategyAdapterHarvestable.HarvestAddresses memory harvestAddresses = StrategyAdapterHarvestable.HarvestAddresses({
            swapper: addressbook.getGoatSwapper(block.chainid),
            wrappedGas: addressbook.getWrappedGas(block.chainid)
        });
        SiloV2VaultAdapter.SiloV2VaultAddresses memory siloV2Addresses = SiloV2VaultAdapter.SiloV2VaultAddresses({
            incentivesController: notificactionReceivers[0],
            idleMarket: idle_market
        });

        vm.startBroadcast();


        SiloV2VaultAdapter adapter = new SiloV2VaultAdapter(multistrategy, asset, silo_vault, siloV2Addresses, harvestAddresses, name, "SILO-V2-VAULT");

        for(uint i = 0; i < rewards.length; ++i) {
            adapter.addReward(rewards[i]);
        }

        adapter.enableGuardian(guardian);
        adapter.transferOwnership(manager);

        vm.stopBroadcast();

        console.log("Silo V2 Vault Adapter:", address(adapter));
    }
}