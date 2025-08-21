// SPDX-License-Identifier: MIT
pragma solidity^0.8.20;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import { ISiloV2Market } from "interfaces/silo/ISiloV2Market.sol";
import { ISiloHookReceiver } from "interfaces/silo/ISiloHookReceiver.sol";
import { ISiloV2IncentivesController } from "interfaces/silo/ISiloV2IncentivesController.sol";
import { SiloV2Adapter } from "src/infra/multistrategy/adapters/SiloV2Adapter.sol";
import { StrategyAdapterHarvestable } from "src/abstracts/StrategyAdapterHarvestable.sol";
import { Addressbook } from "@addressbook/AddressBook.sol";

/// @title Deploys a SiloV2 Market Adapter
contract DeploySiloV2Adapter is Script {
    Addressbook addressbook = new Addressbook();

    function run(
        address multistrategy,
        string memory name,
        address silo_market,
        address[] memory rewards
    ) public {

        require(multistrategy != address(0), "Multistrategy cannot be zero address");

        address asset = IERC4626(multistrategy).asset();
        address manager = addressbook.getManager(block.chainid);
        address guardian = addressbook.getGuardian(block.chainid);
        address incentivesController = ISiloHookReceiver(ISiloV2Market(silo_market).hookReceiver()).configuredGauges(silo_market);

        require(asset == IERC4626(silo_market).asset(), "Silo Market asset missmatch");
        require(silo_market == ISiloV2IncentivesController(incentivesController).SHARE_TOKEN(), "Incentives Controller missmatch");

        StrategyAdapterHarvestable.HarvestAddresses memory harvestAddresses = StrategyAdapterHarvestable.HarvestAddresses({
            swapper: addressbook.getGoatSwapper(block.chainid),
            wrappedGas: addressbook.getWrappedGas(block.chainid)
        });

        vm.startBroadcast();

        SiloV2Adapter adapter = new SiloV2Adapter(multistrategy, asset, silo_market, incentivesController, harvestAddresses, name, "SILO-V2");

        for(uint i = 0; i < rewards.length; ++i) {
            adapter.addReward(rewards[i]);
        }

        adapter.enableGuardian(guardian);
        adapter.transferOwnership(manager);

        vm.stopBroadcast();
    }
}