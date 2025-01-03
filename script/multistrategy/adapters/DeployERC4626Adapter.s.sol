// SPDX-License-Identifier: MIT
pragma solidity^0.8.20;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { ERC4626Adapter } from "src/infra/multistrategy/adapters/ERC4626Adapter.sol";
import { AssetsArbitrum } from "@addressbook/AssetsArbitrum.sol";
import { ProtocolArbitrum } from "@addressbook/ProtocolArbitrum.sol";

contract DeployERC4626Adapter is Script {
    address constant VAULT = 0x74E6AFeF5705BEb126C6d3Bf46f8fad8F3e07825;

    /////////////////////////////////////////////////////////
    //                   ADAPTER CONFIG                    //
    /////////////////////////////////////////////////////////
    address constant MULTISTRATEGY = 0x0df2e3a0b5997AdC69f8768E495FD98A4D00F134; //FIXME:
    address constant ASSET = AssetsArbitrum.USDC;
    address constant GUARDIAN = 0xbd297B4f9991FD23f54e14111EE6190C4Fb9F7e1;
    address constant TESTING_CUSTODIAN = 0x75cb5d555933fe86E0ac8975A623aCb5CEC13E28;
    string constant NAME = "Revert USDC";                            //FIXME:
    string constant ID = "REVERT";

    function run() public {

        /////////////////////////////////////////////////////////
        //                 ADAPTER DEPLOYMENT                  //
        /////////////////////////////////////////////////////////

        vm.startBroadcast();

        ERC4626Adapter adapter = new ERC4626Adapter(MULTISTRATEGY, ASSET, VAULT, NAME, ID);

        adapter.enableGuardian(GUARDIAN);
        adapter.transferOwnership(TESTING_CUSTODIAN);

        vm.stopBroadcast();

        console.log("ERC4626 Adapter:", address(adapter));
    }
}