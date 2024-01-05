// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { GoatFarmFactory } from "../src/infra/GoatFarmFactory.sol";
import { IGoatFarm } from "../src/interfaces/infra/IGoatFarm.sol";

contract DeployFarm is Script {

    address private goa = vm.envAddress("GOA_L2");
    address[] private tokens = [vm.envAddress("WBTC_L2"),
                                vm.envAddress("WETH_L2"),
                                vm.envAddress("ARB_L2"),
                                vm.envAddress("LINK_L2")];

    GoatFarmFactory private factory;
    uint256 private duration = 7 days;

    function run() public {
        uint privateKey = vm.envUint("DEPLOY_PK");
        address account = vm.addr(privateKey);
        address treasury = vm.envAddress("TREASURY_ADDRESS_L2");
        address timelock = vm.envAddress("TIMELOCK_L2");

        console.log("Account", account);

        vm.startBroadcast(privateKey);

        factory = new GoatFarmFactory();

        for (uint i = 0; i < tokens.length; i++) {
            IGoatFarm farm = IGoatFarm(factory.createFarm(tokens[i], goa, duration));
            farm.setNotifier(treasury, true);
            farm.transferOwnership(timelock);
        }

        vm.stopBroadcast();
    }
}