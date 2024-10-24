// SPDX-License-Identifier: MIT
pragma solidity^0.8.20;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";

interface IOwnable {
    function transferOwnership(address newOwner) external;
    function owner() external view returns (address);
}

contract TransferOwnershipMainnet is Script {
    address private mainnetTimelock = vm.envAddress("MAINNET_TIMELOCK");
    address private xgoaMainnet = vm.envAddress("XGOA_MAINNET");
    address private mainnetBridgeAdapter = vm.envAddress("MAINNET_BRIDGEADAPTER");
    uint16 private dstChainId = uint16(vm.envUint("LZ_L2_CHAINID"));

    function run() public {
        uint privateKey = vm.envUint("DEPLOY_PK");
        address account = vm.addr(privateKey);

        console.log("Account", account);

        vm.startBroadcast(privateKey);

        IOwnable(mainnetBridgeAdapter).transferOwnership(mainnetTimelock);
        IOwnable(xgoaMainnet).transferOwnership(mainnetTimelock);

        vm.stopBroadcast();

        console.log(IOwnable(mainnetBridgeAdapter).owner());
        console.log(IOwnable(xgoaMainnet).owner());
    }
}