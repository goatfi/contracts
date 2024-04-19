// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import { IBoostFactory } from "interfaces/infra/IBoostFactory.sol";
import { ProtocolArbitrum } from "@addressbook/ProtocolArbitrum.sol";
import { AssetsArbitrum } from "@addressbook/AssetsArbitrum.sol";

contract DeployGoatBoost is Script {

    address boostFactory; //TODO: Add boost factory address via addresbook

    address vaultToBoost;
    address rewardToken = AssetsArbitrum.VRSW;
    uint256 boostDuration = 21 days;
    address manager = ProtocolArbitrum.TREASURY;
    address treasury = ProtocolArbitrum.TREASURY;

    function run() public {
        vm.startBroadcast();

        address boostAddress = IBoostFactory(boostFactory).deployBoost(vaultToBoost, rewardToken, boostDuration, manager, treasury);

        vm.stopBroadcast();

        console.log("Boost deployed at:", boostAddress);
    }
}