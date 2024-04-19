// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import { GoatBoost } from "src/infra/boost/GoatBoost.sol";
import { BoostFactory } from "src/infra/boost/BoostFactory.sol";
import { ProtocolArbitrum } from "@addressbook/ProtocolArbitrum.sol";

contract DeployBoostFactoryScript is Script {
    address factory = ProtocolArbitrum.GOAT_VAULT_FACTORY;
    address boostImpl;

    function run() public {
        vm.startBroadcast();

        boostImpl = address(new GoatBoost());
        BoostFactory boostFactory = new BoostFactory(factory, boostImpl);
        
        console.log("Deployed BoostFactory at:", address(boostFactory));

        vm.stopBroadcast();
    }
}