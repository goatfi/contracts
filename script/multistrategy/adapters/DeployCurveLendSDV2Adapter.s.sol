// SPDX-License-Identifier: MIT
pragma solidity^0.8.20;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import { CurveLendSDV2Adapter } from "src/infra/multistrategy/adapters/CurveLendSDV2Adapter.sol";
import { StrategyAdapterHarvestable } from "src/abstracts/StrategyAdapterHarvestable.sol";
import { Addressbook } from "@addressbook/AddressBook.sol";

/// @title Deploys a Curve Lend Adapter staked on StakeDAO
contract DeployCurveLendSDV2Adapter is Script {
    Addressbook addressbook = new Addressbook();

    function run(
        address multistrategy,
        string memory name, 
        address curve_lend_vault, 
        address stake_dao_vault,
        address[] memory rewards
    ) public {

        address asset = IERC4626(multistrategy).asset();
        address manager = addressbook.getManager(block.chainid);
        address guardian = addressbook.getGuardian(block.chainid);

        StrategyAdapterHarvestable.HarvestAddresses memory harvestAddresses = StrategyAdapterHarvestable.HarvestAddresses({
            swapper: addressbook.getGoatSwapper(block.chainid),
            wrappedGas: addressbook.getWrappedGas(block.chainid)
        });

        CurveLendSDV2Adapter.CurveLendSDV2Addresses memory crvLendSDV2Addresses = CurveLendSDV2Adapter.CurveLendSDV2Addresses({
            lendVault: curve_lend_vault,
            sdVault: stake_dao_vault
        });

        vm.startBroadcast();

        CurveLendSDV2Adapter adapter = new CurveLendSDV2Adapter(multistrategy, asset, harvestAddresses, crvLendSDV2Addresses, name, "CRV-LEND-SDV2");

        for(uint i = 0; i < rewards.length; ++i) {
            adapter.addReward(rewards[i]);
        }

        adapter.enableGuardian(guardian);
        adapter.transferOwnership(manager);

        vm.stopBroadcast();

        console.log("CRV Lend StakeDAO Adapter:", address(adapter));
    }
}