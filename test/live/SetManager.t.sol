// SPDX-License-Identifier: MIT
pragma solidity^0.8.20;

import { Test } from "forge-std/Test.sol";
import { console } from "forge-std/console.sol";
import { ITimelock} from "interfaces/infra/ITimelock.sol";
import { IMultistrategy } from "interfaces/infra/multistrategy/IMultistrategy.sol";
import { ProtocolArbitrum, VaultsArbitrum, ProtocolSonic, VaultsSonic } from "@addressbook/AddressBook.sol";
contract SetManagerViaTimelock is Test {
    address multi = VaultsSonic.ycUSDCe;
    uint256 time = 43200;

    address newManager = 0x97c7808A1b47b1C60f7ab70C384979412D2A20B6;

    function setUp() public {
        vm.createSelectFork(vm.envString("SONIC_RPC_URL"));
    }

    function test_setManager() public { 
        bytes memory data = abi.encodeWithSignature("setManager(address)", newManager);
        console.logBytes(data);

        vm.prank(ProtocolSonic.TREASURY); ITimelock(ProtocolSonic.TIMELOCK).schedule(multi, 0, data, 0, 0, time);
        vm.warp(block.timestamp + 24 hours);
        vm.prank(ProtocolSonic.TREASURY); ITimelock(ProtocolSonic.TIMELOCK).execute(multi, 0, data, 0, 0);

        address manager = IMultistrategy(multi).manager();
        assertEq(manager, newManager);
    }
}