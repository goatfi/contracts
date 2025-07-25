// SPDX-License-Identifier: MIT
pragma solidity^0.8.20;

import { Test } from "forge-std/Test.sol";
import { console } from "forge-std/console.sol";
import { ITimelock} from "interfaces/infra/ITimelock.sol";
import { IMultistrategy } from "interfaces/infra/multistrategy/IMultistrategy.sol";
import { ProtocolArbitrum, VaultsArbitrum, ProtocolSonic, VaultsSonic } from "@addressbook/AddressBook.sol";

contract SetFeeRecipient is Test {
    address multi = VaultsArbitrum.ycETH;
    uint256 time = 43200;

    function setUp() public {
        vm.createSelectFork(vm.envString("ARBITRUM_RPC_URL"));
    }

    function test_setFeeRecipient() public { 
        bytes memory data = abi.encodeWithSignature("setProtocolFeeRecipient(address)", ProtocolArbitrum.TREASURY);
        console.logBytes(data);

        vm.prank(ProtocolArbitrum.TREASURY); ITimelock(ProtocolArbitrum.TIMELOCK).schedule(multi, 0, data, 0, 0, time);
        vm.warp(block.timestamp + 24 hours);
        vm.prank(ProtocolArbitrum.TREASURY); ITimelock(ProtocolArbitrum.TIMELOCK).execute(multi, 0, data, 0, 0);

        address feeRecipeint = IMultistrategy(multi).protocolFeeRecipient();
        assertEq(feeRecipeint, ProtocolArbitrum.TREASURY);
    }
}