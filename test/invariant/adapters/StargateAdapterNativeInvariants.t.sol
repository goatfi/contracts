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
import { StargateAdapterNative } from "src/infra/multistrategy/adapters/StargateAdapterNative.sol";

contract StargateAdapterNativeInvariants is AdapterInvariantBase {
    AdapterHandler handler;

    function setUp() public override {
        vm.createSelectFork(vm.envString("ARBITRUM_RPC_URL"));
        asset = AssetsArbitrum.WETH;
        super.setUp();
        
        handler = new AdapterHandler(
            createMultistrategy(asset, 1_000 * (10 ** decimals)), 
            createAdapter(), 
            users,
            true
        );

        makeInitialDeposit(10 * (10 ** decimals));
        targetContract(address(handler));
    }

    function createAdapter() public returns (StargateAdapterNative) {
        StrategyAdapterHarvestable.HarvestAddresses memory harvestAddresses = StrategyAdapterHarvestable.HarvestAddresses({
            swapper: ProtocolArbitrum.GOAT_SWAPPER,
            wrappedGas: AssetsArbitrum.WETH
        });

        StargateAdapterNative.StargateAddresses memory stargateAddresses = StargateAdapterNative.StargateAddresses({
            router: 0xA45B5130f36CDcA45667738e2a258AB09f4A5f7F,
            chef: 0x3da4f8E456AC648c489c286B99Ca37B666be7C4C
        });

        StargateAdapterNative adapter = new StargateAdapterNative(address(multistrategy), multistrategy.asset(), harvestAddresses, stargateAddresses, "", "");
        adapter.transferOwnership(users.keeper);
        vm.prank(users.keeper); adapter.addReward(0x6694340fc020c5E6B96567843da2df01b2CE1eb6); // STG
        vm.prank(users.keeper); adapter.enableGuardian(users.guardian);
        vm.prank(users.owner); multistrategy.addStrategy(address(adapter), 10_000, 0, type(uint256).max);

        return adapter;
    }

    function invariant_pricePerShare() public view {
        console.log("Deposited:", handler.ghost_deposited());
        console.log("Withdrawn:", handler.ghost_withdrawn());
        console.log("Yield Time:", handler.ghost_yieldTime());

        if(handler.ghost_yieldTime() > 0 && handler.ghost_deposited() > 0) {
            assertGt(multistrategy.pricePerShare(), 1 * (10 ** decimals));
        }
    }
}