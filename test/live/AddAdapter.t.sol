// SPDX-License-Identifier: MIT
pragma solidity^0.8.20;

import { Test } from "forge-std/Test.sol";
import { console } from "forge-std/console.sol";
import { ITimelock} from "interfaces/infra/ITimelock.sol";
import { IMultistrategy } from "interfaces/infra/multistrategy/IMultistrategy.sol";
import { ProtocolArbitrum, VaultsArbitrum } from "@addressbook/AddressBook.sol";
import { MStrat } from "src/types/DataTypes.sol";

contract AddAdapterViaTimelock is Test {
    address multi = VaultsArbitrum.ycETH;
    address adapter = 0xd937b82848149982AFCd8b0995Bc2c84DBCfBC22;
    uint256 minDebtDelta = 0;
    uint256 maxDebtDelta = type(uint256).max;
    uint256 time = 43200;
    function setUp() public {
        vm.createSelectFork(vm.envString("ARBITRUM_RPC_URL"));
    }

    function test_addAdapter() public { 
        bytes memory data = abi.encodeWithSignature("addStrategy(address,uint256,uint256,uint256)", adapter,0, minDebtDelta, maxDebtDelta);
        console.logBytes(data);

        vm.prank(ProtocolArbitrum.TREASURY); ITimelock(ProtocolArbitrum.TIMELOCK).schedule(multi, 0, data, 0, 0, time);
        vm.warp(block.timestamp + 24 hours);
        vm.prank(ProtocolArbitrum.TREASURY); ITimelock(ProtocolArbitrum.TIMELOCK).execute(multi, 0, data, 0, 0);

        MStrat.StrategyParams memory parameters = IMultistrategy(multi).getStrategyParameters(adapter);
        assertGt(parameters.activation, 0);
    }
}