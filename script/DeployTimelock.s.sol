// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {CreateXScript} from "createx/script/CreateXScript.sol";
import { console } from "forge-std/console.sol";
import { TimelockController } from "@openzeppelin/contracts/governance/TimelockController.sol";
import { ProtocolArbitrum, AssetsArbitrum } from "@addressbook/GoatAddressBook.sol";

contract DeployTimelock is CreateXScript {

    uint256 minDelay = 43200;
    address[] proposers = [0xd132631A63af5C616e60606025C8e5871ADdF76f];
    address[] executors = [0xd132631A63af5C616e60606025C8e5871ADdF76f];

    function setUp() public withCreateX {}
    
    function run() public {
        vm.startBroadcast();
            // Prepare the salt
            bytes32 salt = bytes32(abi.encodePacked(msg.sender, hex"00", bytes11(uint88(123))));

            // Calculate the predetermined address of the contract
            address computedAddress = computeCreate3Address(salt, msg.sender);

            // Deploy using CREATE3
            address deployedAddress = create3(salt, abi.encodePacked(type(TimelockController).creationCode, abi.encode(minDelay, proposers, executors, address(0))));

            // Check to make sure that contract is on the expected address
            require(computedAddress == deployedAddress);
        vm.stopBroadcast();

        console.log("Computed Timelock Address", address(computedAddress));
        console.log("Deployed Timelock Address", address(deployedAddress));
    }
}