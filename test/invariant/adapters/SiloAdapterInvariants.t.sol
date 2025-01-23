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
import { SiloAdapter } from "src/infra/multistrategy/adapters/SiloAdapter.sol";
import { StrategyAdapterHarvestable } from "src/abstracts/StrategyAdapterHarvestable.sol";
import { IStrategyAdapterHarvestable } from "interfaces/infra/multistrategy/IStrategyAdapterHarvestable.sol";


contract SiloAdapterInvariants is AdapterInvariantBase {
    AdapterHandler handler;
    address asset = AssetsArbitrum.WETH;

    function setUp() public {
        vm.createSelectFork(vm.envString("ARBITRUM_RPC_URL"));

        createUsers();
        handler = new AdapterHandler(
            createMultistrategy(asset, 1_000 * (10 ** IERC20Metadata(asset).decimals())), 
            createAdapter(), 
            users,
            true
        );

        makeInitialDeposit(0.01 ether);
        targetContract(address(handler));
    }

    function createAdapter() public returns (SiloAdapter) {
        SiloAdapter.SiloAddresses memory siloAddresses = SiloAdapter.SiloAddresses({
            silo: 0x1182559e5cf2247e4DdB7a38e28a88ec3825f2BA,
            collateral: 0x95633979ae07b857a5A03BbA349EAE891E27fB5E,
            siloLens: 0xBDb843c7a7e48Dc543424474d7Aa63b61B5D9536,
            siloRewards: 0xbDBBf747402653A5aD6F6B8c49F2e8dCeC37fAcF,
            merklDistributor: 0x3Ef3D8bA38EBe18DB133cEc108f4D14CE00Dd9Ae
        });

        StrategyAdapterHarvestable.HarvestAddresses memory harvestAddresses = StrategyAdapterHarvestable.HarvestAddresses({
            swapper: ProtocolArbitrum.GOAT_SWAPPER,
            wrappedGas: AssetsArbitrum.WETH
        });

        SiloAdapter adapter = new SiloAdapter(address(multistrategy), multistrategy.asset(), harvestAddresses, siloAddresses, "", "");
        adapter.transferOwnership(users.keeper);
        vm.prank(users.keeper); adapter.addReward(AssetsArbitrum.SILO);
        vm.prank(users.keeper); adapter.enableGuardian(users.guardian);
        vm.prank(users.owner); multistrategy.addStrategy(address(adapter), 10_000, 0, type(uint256).max);

        return adapter;
    }

    function invariant_pricePerShare() public view {
        console.log("Deposited:", handler.ghost_deposited());
        console.log("Withdrawn:", handler.ghost_withdrawn());
        console.log("Yield Time:", handler.ghost_yieldTime());

        if(handler.ghost_yieldTime() > 0 && handler.ghost_deposited() > 0) {
            assertGt(multistrategy.pricePerShare(), 1 ether);
        }
    }
}