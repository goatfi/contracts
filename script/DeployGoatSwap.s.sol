// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { GoatSwapper } from "src/infra/GoatSwapper.sol";
import { ProtocolArbitrum, AssetsArbitrum } from "@addressbook/GoatAddressBook.sol";

contract DeployGoatSwap is Script {

    address wNative = 0x039e2fB66102314Ce7b64Ce5Ce3E5183bc94aD38;
    address keeper = 0xbd297B4f9991FD23f54e14111EE6190C4Fb9F7e1;
    function run() public {
        vm.startBroadcast();
            GoatSwapper goatSwapper = new GoatSwapper(wNative, keeper);
        vm.stopBroadcast();

        console.log("Goat Swapper", address(goatSwapper));
    }
}