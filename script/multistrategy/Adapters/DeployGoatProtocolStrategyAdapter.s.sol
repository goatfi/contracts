// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { GoatProtocolStrategyAdapter } from "src/infra/multistrategy/adapters/GoatProtocolAdapter.sol";
import { AssetsArbitrum } from "@addressbook/AssetsArbitrum.sol";
import { ProtocolArbitrum } from "@addressbook/ProtocolArbitrum.sol";

contract DeployGoatProtocolStrategyAdapter is Script {
    address constant MULTISTRATEGY = address(0);
    address constant ASSET = AssetsArbitrum.WETH;
    address constant GOAT_VAULT = address(0);

    address constant GUARDIAN = 0xbd297B4f9991FD23f54e14111EE6190C4Fb9F7e1;
    address constant MANAGER = ProtocolArbitrum.TREASURY;

    function run() public { 
        vm.startBroadcast();

        GoatProtocolStrategyAdapter adapter = new GoatProtocolStrategyAdapter(MULTISTRATEGY, ASSET, GOAT_VAULT);

        // Enable a Guardian
        adapter.enableGuardian(GUARDIAN);

        // Transfer Ownership to the Treasury
        adapter.transferOwnership(MANAGER);

        vm.stopBroadcast();

        console.log("Goat Protocol Adapter:", address(adapter));
    }   
}