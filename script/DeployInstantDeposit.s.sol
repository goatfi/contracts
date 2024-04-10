// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { InstantDepositRouter } from "src/infra/instantDeposit/InstantDepositRouter.sol";

contract DeployInstantDeposit is Script {

    function run() public {
        uint deployer_privateKey = vm.envUint("DEPLOY_PK");
        address deployer = vm.addr(deployer_privateKey);
        InstantDepositRouter instantDeposit;

        address permit2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;

        console.log("Deployer", deployer);

        vm.startBroadcast(deployer_privateKey);

        instantDeposit = new InstantDepositRouter(permit2);

        vm.stopBroadcast();

        console.log("InstantDeposit", address(instantDeposit));
    }
}