// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { console } from "forge-std/console.sol";
import { AdapterInvariantBase } from "./AdapterInvariantBase.t.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import { AdapterHandler } from "./AdapterHandler.t.sol";
import { AssetsArbitrum, ProtocolArbitrum } from "@addressbook/AddressBook.sol";
import { Users } from "../../utils/Types.sol";
import { ERC4626Adapter } from "src/infra/multistrategy/adapters/ERC4626Adapter.sol";

contract ERC4626AdapterInvariants is AdapterInvariantBase {
    AdapterHandler handler;

    function setUp() public override {
        vm.createSelectFork(vm.envString("ARBITRUM_RPC_URL"));
        asset = AssetsArbitrum.USDC;
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

    function createAdapter() public returns (ERC4626Adapter) {
        address vault = 0x940098b108fB7D0a7E374f6eDED7760787464609; //Spark USDC

        ERC4626Adapter adapter = new ERC4626Adapter(address(multistrategy), multistrategy.asset(), vault, "", "");
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
    }
}