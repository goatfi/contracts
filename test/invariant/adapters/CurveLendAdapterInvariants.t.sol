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
import { CurveLendAdapter } from "src/infra/multistrategy/adapters/CurveLendAdapter.sol";

contract CurveLendAdapterInvariants is AdapterInvariantBase {
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

    function createAdapter() public returns (CurveLendAdapter) {
        StrategyAdapterHarvestable.HarvestAddresses memory harvestAddresses = StrategyAdapterHarvestable.HarvestAddresses({
            swapper: ProtocolArbitrum.GOAT_SWAPPER,
            wrappedGas: AssetsArbitrum.WETH
        });
        CurveLendAdapter.CurveLendAddresses memory curveLendAddresses = CurveLendAdapter.CurveLendAddresses({
            vault: 0xe07f1151887b8FDC6800f737252f6b91b46b5865,
            gauge: address(0)
        });

        CurveLendAdapter adapter = new CurveLendAdapter(address(multistrategy), multistrategy.asset(), harvestAddresses, curveLendAddresses,"", "");
        adapter.transferOwnership(users.keeper);
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
        assertGt(handler.adapter().availableLiquidity(), 0);
    }
}