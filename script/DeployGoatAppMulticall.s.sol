// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { GoatAppMulticall } from "src/utils/GoatAppMulticall.sol";
import { ProtocolArbitrum, AssetsArbitrum } from "@addressbook/GoatAddressBook.sol";

contract DeployGoatAppMulticall is Script {
    function run() public {
        vm.startBroadcast();
            GoatAppMulticall goatAppMulticall = new GoatAppMulticall(AssetsArbitrum.WETH, ProtocolArbitrum.GOAT_REWARD_POOL);
        vm.stopBroadcast();

        console.log("Goat App Multicall", address(goatAppMulticall));
    }
}