// SPDX-License-Identifier: MIT
pragma solidity^0.8.20;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { GoatRewardPool } from "src/infra/GoatRewardPool.sol";
import { GoatFeeBatch } from "src/infra/GoatFeeBatch.sol";
import { ProtocolArbitrum } from "@addressbook/ProtocolArbitrum.sol";
import { AssetsArbitrum } from "@addressbook/AssetsArbitrum.sol";

contract DeployRewardPool is Script {

    function run() public {
        uint deployer_privateKey = vm.envUint("DEPLOY_PK");
        address deployer = vm.addr(deployer_privateKey);
        
        address treasury = ProtocolArbitrum.TREASURY;
        address goa = AssetsArbitrum.GOA;
        address weth = AssetsArbitrum.WETH;

        console.log("Deployer", deployer);

        vm.startBroadcast(deployer_privateKey);

        GoatRewardPool rewardPool = new GoatRewardPool(goa);
        GoatFeeBatch feeBatch = new GoatFeeBatch(weth, address(rewardPool), treasury, 0);
        
        rewardPool.setWhitelist(address(feeBatch), true);

        vm.stopBroadcast();

        console.log("RP", address(rewardPool));
        console.log("FB", address(feeBatch));
    }
}