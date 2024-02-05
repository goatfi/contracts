// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { GoatAppMulticall } from "src/utils/GoatAppMulticall.sol";

contract DeployAppMulticall is Script {

    function run() public {
        uint privateKey = vm.envUint("DEPLOY_PK");
        address account = vm.addr(privateKey);

        console.log("Account", account);

        vm.startBroadcast(privateKey);

        address appMulticall = address(new GoatAppMulticall(address(0), address(0)));

        vm.stopBroadcast();

        console.log("App Mulitcall", address(appMulticall));
    }
}