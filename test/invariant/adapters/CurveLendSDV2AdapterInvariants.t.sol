// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { console } from "forge-std/console.sol";
import { AdapterInvariantBase } from "./AdapterInvariantBase.t.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import { AdapterHandler } from "./AdapterHandler.t.sol";
import { AssetsArbitrum, ProtocolArbitrum } from "@addressbook/AddressBook.sol";
import { Users } from "../../utils/Types.sol";
import { StrategyAdapterHarvestable } from "src/abstracts/StrategyAdapterHarvestable.sol";
import { CurveLendSDV2Adapter } from "src/infra/multistrategy/adapters/CurveLendSDV2Adapter.sol";

contract CurveLendSDV2AdapterInvariants is AdapterInvariantBase {
    address[] rewards = [AssetsArbitrum.CRV];
    AdapterHandler handler;

    function setUp() public override {
        vm.createSelectFork(vm.envString("ARBITRUM_RPC_URL"));
        asset = AssetsArbitrum.CRVUSD;
        super.setUp();

        handler = new AdapterHandler(
            createMultistrategy(asset, 1_000_000 * (10 ** decimals)), 
            createAdapter(), 
            users,
            false
        );

        makeInitialDeposit(10 * (10 ** decimals));
        targetContract(address(handler));
    }

    function createAdapter() public returns (CurveLendSDV2Adapter) {
        StrategyAdapterHarvestable.HarvestAddresses memory harvestAddresses = StrategyAdapterHarvestable.HarvestAddresses({
            swapper: ProtocolArbitrum.GOAT_SWAPPER,
            wrappedGas: AssetsArbitrum.WETH
        });
        CurveLendSDV2Adapter.CurveLendSDV2Addresses memory curveLendSDAddresses = CurveLendSDV2Adapter.CurveLendSDV2Addresses({
            lendVault: 0xa6C2E6A83D594e862cDB349396856f7FFE9a979B,
            sdVault: 0x17E876675258DeE5A7b2e2e14FCFaB44F867896c
        });

        CurveLendSDV2Adapter adapter = new CurveLendSDV2Adapter(address(multistrategy), multistrategy.asset(), harvestAddresses, curveLendSDAddresses,"", "");
        adapter.transferOwnership(users.keeper);
        vm.prank(users.keeper); adapter.enableGuardian(users.guardian);
        vm.prank(users.owner); multistrategy.addStrategy(address(adapter), 10_000, 0, type(uint256).max);
        for(uint i = 0; i < rewards.length; ++i) {
            vm.prank(users.keeper); adapter.addReward(rewards[i]);
        }

        return adapter;
    }

    function invariant_pricePerShare() public view {
        console.log("Deposited:", handler.ghost_deposited());
        console.log("Withdrawn:", handler.ghost_withdrawn());
        console.log("Yield Time:", handler.ghost_yieldTime());

        if(handler.ghost_yieldTime() > 0 && handler.ghost_deposited() > 0) {
            assertGe(multistrategy.pricePerShare(), 1 * (10 ** decimals));
        }
    }
}