// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { LayerZeroBridgeAdapter } from "../src/infra/bridgeAdapter/LayerZeroBridgeAdapter.sol";

interface ILZBridgeAdapter {
    function setTrustedRemote(uint16 _remoteChainId, bytes calldata _path) external;
}

contract SetLZBridgeConfig_L2 is Script {

    address private mainnetBridgeAdapter = vm.envAddress("MAINNET_BRIDGEADAPTER");
    address private l2BridgeAdapter = vm.envAddress("L2_BRIDGEADAPTER");
    uint16 private dstChainId = uint16(vm.envUint("LZ_MAINNET_CHAINID"));

    ILZBridgeAdapter bridgeAdapter = ILZBridgeAdapter(l2BridgeAdapter);

    function run() public {
        uint privateKey = vm.envUint("DEPLOY_PK");
        address account = vm.addr(privateKey);

        console.log("Account", account);

        vm.startBroadcast(privateKey);

        bytes memory route = abi.encodePacked(mainnetBridgeAdapter, l2BridgeAdapter);
        bytes memory data = abi.encodeWithSignature("setTrustedRemote(uint16,bytes)", dstChainId, route);

        vm.stopBroadcast();

        console.logBytes(route);
        console.logBytes(data);
    }
}