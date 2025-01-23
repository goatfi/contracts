// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { console } from "forge-std/console.sol";
import { AdapterInvariantBase } from "./AdapterInvariantBase.t.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import { AdapterHandler } from "./AdapterHandler.t.sol";
import { AssetsArbitrum } from "@addressbook/AssetsArbitrum.sol";
import { ProtocolArbitrum } from "@addressbook/ProtocolArbitrum.sol";
import { Users } from "../../utils/Types.sol";
import { StrategyAdapterHarvestable } from "src/abstracts/StrategyAdapterHarvestable.sol";
import { StargateAdapter } from "src/infra/multistrategy/adapters/StargateAdapter.sol";

contract StargateAdapterInvariants is AdapterInvariantBase {
    AdapterHandler handler;
    address asset = AssetsArbitrum.USDC;

    function setUp() public {
        vm.createSelectFork(vm.envString("ARBITRUM_RPC_URL"));

        createUsers();
        handler = new AdapterHandler(
            createMultistrategy(asset, 1_000_000 * (10 ** IERC20Metadata(asset).decimals())), 
            createAdapter(), 
            users,
            true
        );

        makeInitialDeposit(10 * (10 ** IERC20Metadata(asset).decimals()));
        targetContract(address(handler));
    }

    function createAdapter() public returns (StargateAdapter) {
        StrategyAdapterHarvestable.HarvestAddresses memory harvestAddresses = StrategyAdapterHarvestable.HarvestAddresses({
            swapper: ProtocolArbitrum.GOAT_SWAPPER,
            wrappedGas: AssetsArbitrum.WETH
        });

        StargateAdapter.StargateAddresses memory stargateAddresses = StargateAdapter.StargateAddresses({
            router: 0xe8CDF27AcD73a434D661C84887215F7598e7d0d3,
            chef: 0x3da4f8E456AC648c489c286B99Ca37B666be7C4C
        });

        StargateAdapter adapter = new StargateAdapter(address(multistrategy), multistrategy.asset(), harvestAddresses, stargateAddresses, "", "");
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
            assertGe(multistrategy.pricePerShare(), 1 * (10 ** IERC20Metadata(asset).decimals()));
        }
    }
}