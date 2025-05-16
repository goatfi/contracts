// SPDX-License-Identifier: GNU AGPLv3

pragma solidity 0.8.27;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { CurveStableNgSlippageUtility } from "src/infra/utilities/curve/CurveStableNgSlippageUtility.sol";

contract DeployCurveSlippageUtility is Script {
    function run() public {
        vm.startBroadcast();
        address utility = address(new CurveStableNgSlippageUtility());
        vm.stopBroadcast();

        console.log(utility);
    }
}