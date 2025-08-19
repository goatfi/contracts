// SPDX-License-Identifier: MIT
pragma solidity^0.8.20;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import { AaveAdapter } from "src/infra/multistrategy/adapters/AaveAdapter.sol";
import { Addressbook } from "@addressbook/AddressBook.sol";

/// @title Deploys an AAVE Adapter
contract DeployAaveAdapter is Script {
    Addressbook addressbook = new Addressbook();

    function run(
        address multistrategy, 
        string memory name, 
        address aave_pool, 
        address a_token
    ) public {

        address asset = IERC4626(multistrategy).asset();
        address manager = addressbook.getManager(block.chainid);
        address guardian = addressbook.getGuardian(block.chainid);

        vm.startBroadcast();

        AaveAdapter adapter = new AaveAdapter(multistrategy, asset, aave_pool, a_token, name, "AAVE");

        adapter.enableGuardian(guardian);
        adapter.transferOwnership(manager);

        vm.stopBroadcast();
    }
}