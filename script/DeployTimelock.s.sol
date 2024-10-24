// SPDX-License-Identifier: MIT
pragma solidity^0.8.20;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { TimelockController } from "@openzeppelin/contracts/governance/TimelockController.sol";

contract DeployTimelock is Script {

    function run() public {
        uint deployer_privateKey = vm.envUint("DEPLOY_PK");
        address deployer = vm.addr(deployer_privateKey);
        address treasury = vm.envAddress("TREASURY_ADDRESS_L2");
        TimelockController timelock;

        uint mindelay = vm.envUint("TIMELOCK_MIN_DELAY");
        address[] memory proposers = new address[](1);
        address[] memory executors = new address[](1);

        proposers[0] = treasury;
        executors[0] = treasury;

        console.log("Deployer", deployer);

        vm.startBroadcast(deployer_privateKey);

        timelock = new TimelockController(mindelay, proposers, executors, address(0));

        vm.stopBroadcast();

        console.log("Timelock", address(timelock));
    }
}