// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import { StargateAdapterNative } from "src/infra/multistrategy/adapters/StargateAdapterNative.sol";
import { StrategyAdapterHarvestable } from "src/abstracts/StrategyAdapterHarvestable.sol";
import { Addressbook } from "@addressbook/AddressBook.sol";

/// @title Deploys an Stargate Adapter for ETH
contract DeployStargateNativeAdapter is Script {
    Addressbook addressbook = new Addressbook();

    function run(
        address multistrategy,
        string memory name,
        address stargate_router,
        address stargate_chef,
        address[] memory rewards
    ) public {

        address asset = IERC4626(multistrategy).asset();
        address manager = addressbook.getManager(block.chainid);
        address guardian = addressbook.getGuardian(block.chainid);

        StrategyAdapterHarvestable.HarvestAddresses memory harvestAddresses = StrategyAdapterHarvestable.HarvestAddresses({
            swapper: addressbook.getGoatSwapper(block.chainid),
            wrappedGas: addressbook.getWrappedGas(block.chainid)
        });

        StargateAdapterNative.StargateAddresses memory stargateAddresses = StargateAdapterNative.StargateAddresses({
            router: stargate_router,
            chef: stargate_chef
        });

        vm.startBroadcast();

        StargateAdapterNative adapter = new StargateAdapterNative(
            multistrategy,
            asset,
            harvestAddresses,
            stargateAddresses,
            name,
            "STARGATE"
        );

        for (uint i = 0; i < rewards.length; ++i) {
            adapter.addReward(rewards[i]);
        }

        adapter.enableGuardian(guardian);
        adapter.transferOwnership(manager);

        vm.stopBroadcast();

        console.log("Stargate Adapter:", address(adapter));
    }
}
