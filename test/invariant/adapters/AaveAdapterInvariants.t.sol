// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { console } from "forge-std/console.sol";
import { AdapterInvariantBase } from "./AdapterInvariantBase.t.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import { AdapterHandler } from "./AdapterHandler.t.sol";
import { AssetsArbitrum, ProtocolArbitrum } from "@addressbook/AddressBook.sol";
import { Users } from "../../utils/Types.sol";
import { AaveAdapter } from "src/infra/multistrategy/adapters/AaveAdapter.sol";

contract AaveAdapterInvariants is AdapterInvariantBase {
    AdapterHandler handler;

    function setUp() public override {
        vm.createSelectFork(vm.envString("ARBITRUM_RPC_URL"));
        asset = AssetsArbitrum.WETH;
        super.setUp();
        
        handler = new AdapterHandler(
            createMultistrategy(asset, 1_000 * (10 ** decimals)), 
            createAdapter(), 
            users,
            false
        );

        makeInitialDeposit(1 * (10 ** decimals));
        targetContract(address(handler));
    }

    function createAdapter() public returns (AaveAdapter) {
        address aave_pool = 0x794a61358D6845594F94dc1DB02A252b5b4814aD;
        address a_token = 0xe50fA9b3c56FfB159cB0FCA61F5c9D750e8128c8;

        AaveAdapter adapter = new AaveAdapter(address(multistrategy), multistrategy.asset(), aave_pool, a_token,"", "");
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
            assertGe(multistrategy.pricePerShare(), 1 * (10 ** decimals));
        }
    }
}