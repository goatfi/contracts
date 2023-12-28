// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { GOA } from "../src/infra/GOA.sol";
import { IXERC20 } from "@xerc20/interfaces/IXERC20.sol";
import { IXERC20Factory } from "@xerc20/interfaces/IXERC20Factory.sol";
import { IXERC20Lockbox } from "@xerc20/interfaces/IXERC20Lockbox.sol";
import { XERC20Factory } from "@xerc20/contracts/XERC20Factory.sol";
import { LayerZeroBridgeAdapter } from "../src/infra/bridgeAdapter/LayerZeroBridgeAdapter.sol";

contract DeployGOA is Script {

    IERC20 private goa;
    IXERC20 private xgoa;
    IXERC20Factory private factory;
    IXERC20Lockbox private lockbox;
    LayerZeroBridgeAdapter private lz_bridgeAdapter;

    uint256[] private minterLimits = new uint256[](1);
    uint256[] private burnerLimits = new uint256[](1);
    address[] private bridges = new address[](1);
    address[] private neededContracts = new address[](1);

    uint256 private mainnetID = vm.envUint("MAINNET_CHAINID");
    uint256 private l2ID = vm.envUint("L2_CHAINID");
    uint16 private lz_mainnetID = uint16(vm.envUint("LZ_MAINNET_CHAINID"));
    uint16 private lz_l2ID = uint16(vm.envUint("LZ_L2_CHAINID"));

    uint256[] private chainIds = [mainnetID, l2ID];
    uint16[] private lzIds = [lz_mainnetID, lz_l2ID];
    uint256 private gasLimit = vm.envUint("GAS_LIMIT");
    uint256 private bridgeLimit = vm.envUint("BRIDGE_LIMIT");

    function run() public {
        uint privateKey = vm.envUint("DEPLOY_PK");
        address account = vm.addr(privateKey);
        address treasury = vm.envAddress("TREASURY_ADDRESS_MAINNET");
        address lz_endpoint = vm.envAddress("LZ_MAINNET_ENDPOINT");
        address[] memory proposers = new address[](1);
        address[] memory executors = new address[](1);
        proposers[0] = treasury;
        executors[0] = treasury;

        neededContracts[0] = lz_endpoint;

        console.log("Account", account);
        console.log("Treasury", treasury);

        vm.startBroadcast(privateKey);

        goa = IERC20(new GOA(treasury));
        factory = IXERC20Factory(new XERC20Factory());
        xgoa = IXERC20(factory.deployXERC20("xGOA", "xGOA", minterLimits, burnerLimits, bridges));
        lockbox = IXERC20Lockbox(factory.deployLockbox(address(xgoa), address(goa), false));

        lz_bridgeAdapter = new LayerZeroBridgeAdapter();
        lz_bridgeAdapter.initialize(goa, xgoa, lockbox, neededContracts);
        lz_bridgeAdapter.addChainIds(chainIds, lzIds);
        lz_bridgeAdapter.setGasLimit(gasLimit);

        xgoa.setLimits(address(lz_bridgeAdapter), bridgeLimit, bridgeLimit);

        vm.stopBroadcast();

        console.log("GOA", address(goa));
        console.log("xGOA", address(xgoa));
        console.log("Factory", address(factory));
        console.log("Lockbox", address(lockbox));
        console.log("LZ_BridgeAdapter", address(lz_bridgeAdapter));
        console.log("Treasury GOA Balance", goa.balanceOf(treasury));
        console.log(IERC20Metadata(address(goa)).name());
        console.log(IERC20Metadata(address(xgoa)).name());
    }
}