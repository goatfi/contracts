// SPDX-License-Identifier: MIT
pragma solidity^0.8.20;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { Multicall } from "src/utils/Multicall.sol";

contract DeployMulticall is Script {

    function run() public {
        uint privateKey = vm.envUint("DEPLOY_PK");
        address account = vm.addr(privateKey);

        console.log("Account", account);

        vm.startBroadcast(privateKey);

        address multicall = address(new Multicall());

        vm.stopBroadcast();

        console.log("Mulitcall", address(multicall));
    }
}