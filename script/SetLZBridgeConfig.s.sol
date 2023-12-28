// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { LayerZeroBridgeAdapter } from "../src/infra/bridgeAdapter/LayerZeroBridgeAdapter.sol";

interface ILZBridgeAdapter {
    function setTrustedRemote(uint16 _remoteChainId, bytes calldata _path) external;
    function getTrustedRemoteAddress(uint16 _remoteChainId) external view returns (bytes memory);
}

contract SetLZBridgeConfig is Script {

    address private mainnetBridgeAdapter = vm.envAddress("MAINNET_BRIDGEADAPTER");
    address private l2BridgeAdapter = vm.envAddress("L2_BRIDGEADAPTER");
    uint16 private dstChainId = uint16(vm.envUint("LZ_L2_CHAINID"));

    ILZBridgeAdapter bridgeAdapter = ILZBridgeAdapter(mainnetBridgeAdapter);

    function run() public {
        uint privateKey = vm.envUint("DEPLOY_PK");
        address account = vm.addr(privateKey);

        console.log("Account", account);

        vm.startBroadcast(privateKey);

        bridgeAdapter.setTrustedRemote(dstChainId, abi.encodePacked(l2BridgeAdapter, mainnetBridgeAdapter));

        vm.stopBroadcast();

        console.logBytes(bridgeAdapter.getTrustedRemoteAddress(dstChainId));
    }
}