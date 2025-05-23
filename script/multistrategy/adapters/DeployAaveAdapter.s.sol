// SPDX-License-Identifier: MIT
pragma solidity^0.8.20;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { AaveAdapter } from "src/infra/multistrategy/adapters/AaveAdapter.sol";
import { AssetsArbitrum, ProtocolArbitrum, VaultsArbitrum } from "@addressbook/AddressBook.sol";

contract DeployAaveAdapter is Script {
    /////////////////////////////////////////////////////////
    //                   AAVE CONFIG                       //
    /////////////////////////////////////////////////////////
    address constant AAVE_POOL = 0x794a61358D6845594F94dc1DB02A252b5b4814aD;
    address constant A_TOKEN = 0xe50fA9b3c56FfB159cB0FCA61F5c9D750e8128c8;

    /////////////////////////////////////////////////////////
    //                   ADAPTER CONFIG                    //
    /////////////////////////////////////////////////////////
    address constant MULTISTRATEGY = VaultsArbitrum.ycETH;
    address constant ASSET = AssetsArbitrum.WETH;
    address constant GUARDIAN = 0xbd297B4f9991FD23f54e14111EE6190C4Fb9F7e1;
    string constant NAME = "Aave WETH";
    string constant ID = "AAVE";

    function run() public {

        /////////////////////////////////////////////////////////
        //                 ADAPTER DEPLOYMENT                  //
        /////////////////////////////////////////////////////////

        vm.startBroadcast();

        AaveAdapter adapter = new AaveAdapter(MULTISTRATEGY, ASSET, AAVE_POOL, A_TOKEN, NAME, ID);

        adapter.enableGuardian(GUARDIAN);
        adapter.transferOwnership(ProtocolArbitrum.MULTI_MANAGER);

        vm.stopBroadcast();

        console.log("AAVE Adapter:", address(adapter));
    }
}