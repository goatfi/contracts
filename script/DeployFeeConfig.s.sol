// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { Upgrades } from "openzeppelin-foundry-upgrades/Upgrades.sol";
import { FeeConfigurator } from "src/infra/FeeConfigurator.sol";
import { IFeeConfig } from "interfaces/common/IFeeConfig.sol";
import { ProtocolArbitrum } from "@addressbook/ProtocolArbitrum.sol";

contract DeployFeeConfig is Script {

    function run() public {
        uint deployer_privateKey = vm.envUint("DEPLOY_PK");
        address deployer = vm.addr(deployer_privateKey);
        address treasury = ProtocolArbitrum.TREASURY;

        console.log("Deployer", deployer);

        vm.startBroadcast(deployer_privateKey);

        address feeConfig = Upgrades.deployTransparentProxy(
                "FeeConfigurator.sol",
                deployer,
                abi.encodeCall(FeeConfigurator.initialize, (treasury, 0.05 ether)));

        vm.stopBroadcast();

        console.log("FeeConfigurator:", feeConfig);

    }
}