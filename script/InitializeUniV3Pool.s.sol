// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { IPoolInitializer } from "../src/interfaces/uniswap/IPoolInitializer.sol";

contract InitializeUniV3Pool is Script {

    address private WETH = vm.envAddress("WETH_L2");
    address private GOA = vm.envAddress("GOA_L2");
    address private nonfungiblePositionManager = vm.envAddress("UNI_POSITION_MANAGER_L2");
    uint24 private fee = uint24(vm.envUint("LP_FEE"));

    uint256 private p = 1 ether / 0.00005 ether;
    uint160 private sqrtPriceX96 = uint160(Math.sqrt(p) * 2 ** 96);

    function run() public {
        uint deployer_privateKey = vm.envUint("DEPLOY_PK");
        address deployer = vm.addr(deployer_privateKey);

        console.log("Deployer", deployer);

        vm.startBroadcast(deployer_privateKey);

        address pool = IPoolInitializer(nonfungiblePositionManager).createAndInitializePoolIfNecessary(WETH, GOA, fee, sqrtPriceX96);

        vm.stopBroadcast();

        console.log("Pool", pool);
    }
}