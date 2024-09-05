// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { GoatProtocolStrategyAdapter } from "src/infra/multistrategy/adapters/GoatProtocolAdapter.sol";
import { AssetsArbitrum } from "@addressbook/AssetsArbitrum.sol";
import { ProtocolArbitrum } from "@addressbook/ProtocolArbitrum.sol";

contract DeployGoatProtocolStrategyAdapter is Script {

    address TESTING_CUSTODIAN = 0x75cb5d555933fe86E0ac8975A623aCb5CEC13E28;

    address constant MULTISTRATEGY = 0x54aDf00460C7B7874E5b475F413e88878063318a;
    address constant ASSET = AssetsArbitrum.WETH;
    address constant GOAT_VAULT = 0x44f86AE29d4077ABeF56897d5CeD25d9448346Ce;

    address constant GUARDIAN = 0xbd297B4f9991FD23f54e14111EE6190C4Fb9F7e1;
    address constant MANAGER = ProtocolArbitrum.TREASURY;
    string constant NAME = "";
    string constant ID = "GP";

    function run() public { 
        vm.startBroadcast();

        GoatProtocolStrategyAdapter adapter = new GoatProtocolStrategyAdapter(MULTISTRATEGY, ASSET, GOAT_VAULT, NAME, ID);

        // Enable a Guardian
        adapter.enableGuardian(GUARDIAN);

        // Transfer Ownership to the Treasury
        adapter.transferOwnership(TESTING_CUSTODIAN);

        vm.stopBroadcast();

        console.log("Goat Protocol Adapter:", address(adapter));
    }   
}