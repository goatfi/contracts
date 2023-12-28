// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { UniswapPositionHelper, INftPositionManager } from "../src/infra/uniswapHelper/UniswapPositionHelper.sol";

contract DeployUniswapPositionHelper is Script {

    function run() public {
        uint privateKey = vm.envUint("DEPLOY_PK");
        address account = vm.addr(privateKey);
        address nonFungiblePositionManager = vm.envAddress("UNI_POSITION_MANAGER_L2");

        console.log("Account", account);

        vm.startBroadcast(privateKey);

        address uph = address(new UniswapPositionHelper(INftPositionManager(nonFungiblePositionManager)));

        vm.stopBroadcast();

        console.log("Uniswap Position Helper", address(uph));
    }
}