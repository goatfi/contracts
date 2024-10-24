// SPDX-License-Identifier: MIT
pragma solidity^0.8.20;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";

interface ITimelock {
    function schedule(
        address target,
        uint256 value,
        bytes calldata data,
        bytes32 predecessor,
        bytes32 salt,
        uint256 delay
    ) external;

    function execute(
        address target,
        uint256 value,
        bytes calldata payload,
        bytes32 predecessor,
        bytes32 salt
    ) external;

    function scheduleBatch(
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] calldata payloads,
        bytes32 predecessor,
        bytes32 salt,
        uint256 delay
    ) external;

    function executeBatch(
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] calldata payloads,
        bytes32 predecessor,
        bytes32 salt
    ) external;
}

contract ScheduleCall is Script {

    //FeeBatch
    address target = 0xa422b36ea2622BA3312f6c0144419ae7B3c78316;

    function run() public {
        uint deployer_privateKey = vm.envUint("TESTNET_DEPLOY_PK");
        address deployer = vm.addr(deployer_privateKey);
        ITimelock timelock = ITimelock(0xc9f965604467E800A11d30cfbD23298C146c6701);

        console.log("Deployer", deployer);

        vm.startBroadcast(deployer_privateKey);

        bytes memory data = abi.encodeWithSignature("harvest()");
        timelock.schedule(target, 0, data, 0, keccak256(abi.encode(19)), 10);

        vm.stopBroadcast();
    }
}