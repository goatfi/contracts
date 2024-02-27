// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";

contract GenerateEncodedData is Script {

    uint256 id = 1;
    uint256 total = 0;
    uint256 call = 0;
    uint256 strategist = 0;
    string label = "wstGOA";
    bool active = true;
    bool adjust = false;

    function run() public {
        uint privateKey = vm.envUint("DEPLOY_PK");

        vm.startBroadcast(privateKey);

        bytes memory data = abi.encodeWithSignature("setFeeCategory(uint256,uint256,uint256,uint256,string,bool,bool)", id, total, call, strategist, label, active, adjust);

        vm.stopBroadcast();

        console.logBytes(data);
    }
}