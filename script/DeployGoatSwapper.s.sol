// SPDX-License-Identifier: MIT
pragma solidity^0.8.20;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { GoatSwapper } from "src/infra/GoatSwapper.sol";
import { AssetsArbitrum } from "@addressbook/AssetsArbitrum.sol";

contract DeployGoatSwapper is Script {

    function run() public {
        uint deployer_privateKey = vm.envUint("DEPLOY_PK");
        address deployer = vm.addr(deployer_privateKey);
        address keeper = 0xbd297B4f9991FD23f54e14111EE6190C4Fb9F7e1;
        GoatSwapper swapper;

        console.log("Deployer", deployer);

        vm.startBroadcast(deployer_privateKey);

        swapper = new GoatSwapper(AssetsArbitrum.WETH, keeper);

        vm.stopBroadcast();

        console.log("Swapper", address(swapper));
    }
}