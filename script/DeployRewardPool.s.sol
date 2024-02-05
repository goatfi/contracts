// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { GoatRewardPool } from "src/infra/GoatRewardPool.sol";
import { GoatFeeBatch } from "src/infra/GoatFeeBatch.sol";

contract DeployRewardPool is Script {

    function run() public {
        uint deployer_privateKey = vm.envUint("DEPLOY_PK");
        address deployer = vm.addr(deployer_privateKey);
        
        address treasury = vm.envAddress("TREASURY_ADDRESS_ARBITRUM");
        address goa = vm.envAddress("GOA_ARBITRUM");
        address weth = vm.envAddress("WETH_ARBITRUM");

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