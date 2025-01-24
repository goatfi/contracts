// SPDX-License-Identifier: MIT
pragma solidity^0.8.20;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { AaveAdapter } from "src/infra/multistrategy/adapters/AaveAdapter.sol";
import { AssetsArbitrum, ProtocolArbitrum } from "@addressbook/AddressBook.sol";

contract DeployAaveAdapter is Script {
    address constant AAVE_POOL = 0x794a61358D6845594F94dc1DB02A252b5b4814aD;
    address constant A_TOKEN = 0x724dc807b04555b71ed48a6896b6F41593b8C637;

    /////////////////////////////////////////////////////////
    //                   ADAPTER CONFIG                    //
    /////////////////////////////////////////////////////////
    address constant MULTISTRATEGY = 0x0df2e3a0b5997AdC69f8768E495FD98A4D00F134; //FIXME:
    address constant ASSET = AssetsArbitrum.USDC;
    address constant GUARDIAN = 0xbd297B4f9991FD23f54e14111EE6190C4Fb9F7e1;
    address constant TESTING_CUSTODIAN = 0x75cb5d555933fe86E0ac8975A623aCb5CEC13E28;
    string constant NAME = "Aave USDC";                            //FIXME:
    string constant ID = "AAVE";

    function run() public {

        /////////////////////////////////////////////////////////
        //                 ADAPTER DEPLOYMENT                  //
        /////////////////////////////////////////////////////////

        vm.startBroadcast();

        AaveAdapter adapter = new AaveAdapter(MULTISTRATEGY, ASSET, AAVE_POOL, A_TOKEN, NAME, ID);

        adapter.enableGuardian(GUARDIAN);
        adapter.transferOwnership(TESTING_CUSTODIAN);

        vm.stopBroadcast();

        console.log("AAVE Adapter:", address(adapter));
    }
}