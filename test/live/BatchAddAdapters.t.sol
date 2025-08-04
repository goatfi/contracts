// SPDX-License-Identifier: MIT
pragma solidity^0.8.20;

import { Test } from "forge-std/Test.sol";
import { console } from "forge-std/console.sol";
import { ITimelock} from "interfaces/infra/ITimelock.sol";
import { IMultistrategy } from "interfaces/infra/multistrategy/IMultistrategy.sol";
import { ProtocolArbitrum, VaultsArbitrum } from "@addressbook/AddressBook.sol";
import { MStrat } from "src/types/DataTypes.sol";

contract BatchAddAdaptersViaTimelock is Test {
    uint256 minDebtDelta = 0;
    uint256 maxDebtDelta = type(uint256).max;
    uint256 time = 43200;
    function setUp() public {
        vm.createSelectFork(vm.envString("ARBITRUM_RPC_URL"));
    }

    function test_addAdapter() public { 
        address[] memory targets = new address[](5);
        targets[0] = VaultsArbitrum.ycUSDT;
        targets[1] = VaultsArbitrum.ycUSDC;
        targets[2] = VaultsArbitrum.ycCRVUSD;
        targets[3] = VaultsArbitrum.ycCRVUSD;
        targets[4] = VaultsArbitrum.ycCRVUSD;

        uint256[] memory values = new uint256[](5);

        bytes[] memory batchedData = new bytes[](5);
        batchedData[0] = abi.encodeWithSignature("addStrategy(address,uint256,uint256,uint256)", 0xaDE2EDde17791383c999370C25174EAF85586FCB, 0, 1e6, type(uint256).max);
        batchedData[1] = abi.encodeWithSignature("addStrategy(address,uint256,uint256,uint256)", 0x2B14B63355675D3D051a26d731A101c97043C217, 0, 1e6, type(uint256).max);
        batchedData[2] = abi.encodeWithSignature("addStrategy(address,uint256,uint256,uint256)", 0x1e18107b76f8FA056Cb836aa177380b05C006875, 0, 0, type(uint256).max);
        batchedData[3] = abi.encodeWithSignature("addStrategy(address,uint256,uint256,uint256)", 0x6c5d528F774BFFeb8Be08d4d00E3f21a5c9d0C86, 0, 0, type(uint256).max);
        batchedData[4] = abi.encodeWithSignature("addStrategy(address,uint256,uint256,uint256)", 0x390fDf420a36034729830c8eD47D5dEcF48E7946, 0, 0, type(uint256).max);

        vm.prank(ProtocolArbitrum.TREASURY); ITimelock(ProtocolArbitrum.TIMELOCK).scheduleBatch(targets, values, batchedData, 0, 0, time);
        vm.warp(block.timestamp + 24 hours);
        vm.prank(ProtocolArbitrum.TREASURY); ITimelock(ProtocolArbitrum.TIMELOCK).executeBatch(targets, values, batchedData, 0, 0);
    }
}