// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { GoatVaultFactory } from "src/infra/vault/GoatVaultFactory.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

contract DeployGoatVaultFactory is Script {

    function run() public {
        uint deployer_privateKey = vm.envUint("DEPLOY_PK");
        address deployer = vm.addr(deployer_privateKey);
        GoatVaultFactory vaultFactory;

        console.log("Deployer", deployer);

        vm.startBroadcast(deployer_privateKey);

        vaultFactory = new GoatVaultFactory(address(0));

        vm.stopBroadcast();

        console.log("Goat Vault Factory:", address(vaultFactory));
        console.log("Goat Vault Instance:", address(vaultFactory.instance()));
    }
}