// SPDX-License-Identifier: MIT
pragma solidity^0.8.20;

import { Test } from "forge-std/Test.sol";
import { console } from "forge-std/console.sol";
import { ITimelock} from "interfaces/infra/ITimelock.sol";
import { IMultistrategy } from "interfaces/infra/multistrategy/IMultistrategy.sol";
import { ProtocolArbitrum, VaultsArbitrum, ProtocolSonic, VaultsSonic } from "@addressbook/AddressBook.sol";
contract SwapTimelockAdmin is Test {
    uint256 time = 43200;

    address newAdminAddress = ProtocolArbitrum.TREASURY;

    bytes32 CANCELLER_ROLE = 0xfd643c72710c63c0180259aba6b2d05451e3591a24e58b62239378085726f783;
    bytes32 EXECUTOR_ROLE = 0xd8aa0f3194971a2a116679f7c2090f6939c8d4e01a2a8d7e41d55e5351469e63;
    bytes32 PROPOSER_ROLE = 0xb09aa5aeb3702cfd50b6b62bc4532604938f21248a27a1d5ca736082b6819cc1;

    function setUp() public {
        vm.createSelectFork(vm.envString("SONIC_RPC_URL"));
    }

    function test_swapTimelockAdmin() public { 
        bytes memory grantCancellerData = abi.encodeWithSignature("grantRole(bytes32,address)", CANCELLER_ROLE, newAdminAddress);
        bytes memory grantExecutorData = abi.encodeWithSignature("grantRole(bytes32,address)", EXECUTOR_ROLE, newAdminAddress);
        bytes memory grantProposerData = abi.encodeWithSignature("grantRole(bytes32,address)", PROPOSER_ROLE, newAdminAddress);

        bytes memory revokeCancellerData = abi.encodeWithSignature("revokeRole(bytes32,address)", CANCELLER_ROLE, ProtocolSonic.TREASURY);
        bytes memory revokeExecutorData = abi.encodeWithSignature("revokeRole(bytes32,address)", EXECUTOR_ROLE, ProtocolSonic.TREASURY);
        bytes memory revokeProposerData = abi.encodeWithSignature("revokeRole(bytes32,address)", PROPOSER_ROLE, ProtocolSonic.TREASURY);

        address[] memory targets = new address[](6);
        targets[0] = ProtocolSonic.TIMELOCK;
        targets[1] = ProtocolSonic.TIMELOCK;
        targets[2] = ProtocolSonic.TIMELOCK;
        targets[3] = ProtocolSonic.TIMELOCK;
        targets[4] = ProtocolSonic.TIMELOCK;
        targets[5] = ProtocolSonic.TIMELOCK;

        uint256[] memory values = new uint256[](6);
        values[0] = 0;
        values[1] = 0;
        values[2] = 0;
        values[3] = 0;
        values[4] = 0;
        values[5] = 0;


        bytes[] memory data = new bytes[](6);
        data[0] = grantCancellerData;
        data[1] = grantExecutorData;
        data[2] = grantProposerData;
        data[3] = revokeCancellerData;
        data[4] = revokeExecutorData;
        data[5] = revokeProposerData;

        vm.prank(ProtocolSonic.TREASURY); ITimelock(ProtocolSonic.TIMELOCK).scheduleBatch(targets, values, data, 0, 0, time);
        vm.warp(block.timestamp + 24 hours);
        vm.prank(ProtocolSonic.TREASURY); ITimelock(ProtocolSonic.TIMELOCK).executeBatch(targets, values, data, 0, 0);

        bool hasCancellerRole = ITimelock(ProtocolSonic.TIMELOCK).hasRole(CANCELLER_ROLE, ProtocolSonic.TREASURY);
        bool hasExecutorRole = ITimelock(ProtocolSonic.TIMELOCK).hasRole(EXECUTOR_ROLE, ProtocolSonic.TREASURY);
        bool hasProposerRole = ITimelock(ProtocolSonic.TIMELOCK).hasRole(PROPOSER_ROLE, ProtocolSonic.TREASURY);

        assertEq(hasCancellerRole, false);
        assertEq(hasExecutorRole, false);
        assertEq(hasProposerRole, false);

        hasCancellerRole = ITimelock(ProtocolSonic.TIMELOCK).hasRole(CANCELLER_ROLE, newAdminAddress);
        hasExecutorRole = ITimelock(ProtocolSonic.TIMELOCK).hasRole(EXECUTOR_ROLE, newAdminAddress);
        hasProposerRole = ITimelock(ProtocolSonic.TIMELOCK).hasRole(PROPOSER_ROLE, newAdminAddress);

        assertEq(hasCancellerRole, true);
        assertEq(hasExecutorRole, true);
        assertEq(hasProposerRole, true);


        //** VERIFY THAT THE NEW TIMELOCK ADMIN CAN PERFORM ACTIONS */
        address newManager = makeAddr("bob");
        bytes memory setManagerData = abi.encodeWithSignature("setManager(address)", newManager);
        vm.prank(newAdminAddress); ITimelock(ProtocolSonic.TIMELOCK).schedule(VaultsSonic.ycS, 0, setManagerData, 0, 0, time);
        vm.warp(block.timestamp + 24 hours);
        vm.prank(newAdminAddress); ITimelock(ProtocolSonic.TIMELOCK).execute(VaultsSonic.ycS, 0, setManagerData, 0, 0);
        assertEq(IMultistrategy(VaultsSonic.ycS).manager(), newManager);
    }
}