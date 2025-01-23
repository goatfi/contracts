// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { TimelockController } from "@openzeppelin/contracts/governance/TimelockController.sol";
import { ProtocolArbitrum, AssetsArbitrum } from "@addressbook/GoatAddressBook.sol";

contract DeployTimelock is Script {

    uint256 minDelay = 43200;
    address[] proposers = [0xd132631A63af5C616e60606025C8e5871ADdF76f];
    address[] executors = [0xd132631A63af5C616e60606025C8e5871ADdF76f];
    
    function run() public {
        vm.startBroadcast();
            TimelockController timelock = new TimelockController(minDelay, proposers, executors, address(0));
        vm.stopBroadcast();

        console.log("Timelock", address(timelock));
    }
}