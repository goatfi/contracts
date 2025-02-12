// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import { console } from "forge-std/console.sol";
import { AdapterInvariantBase } from "./AdapterInvariantBase.t.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import { AdapterHandler } from "./AdapterHandler.t.sol";
import { AssetsSonic, ProtocolSonic } from "@addressbook/AddressBook.sol";
import { Users } from "../../utils/Types.sol";
import { SiloV2Adapter } from "src/infra/multistrategy/adapters/SiloV2Adapter.sol";
import { StrategyAdapterHarvestable } from "src/abstracts/StrategyAdapterHarvestable.sol";
import { IStrategyAdapterHarvestable } from "interfaces/infra/multistrategy/IStrategyAdapterHarvestable.sol";


contract SiloV2AdapterInvariants is AdapterInvariantBase {
    AdapterHandler handler;
    address asset = AssetsSonic.USDCe;

    function setUp() public {
        vm.createSelectFork(vm.envString("SONIC_RPC_URL"));

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

    function createAdapter() public returns (SiloV2Adapter) {
        address vault = 0x4E216C15697C1392fE59e1014B009505E05810Df;
        address incentivesController = 0x0dd368Cd6D8869F2b21BA3Cb4fd7bA107a2e3752;

        StrategyAdapterHarvestable.HarvestAddresses memory harvestAddresses = StrategyAdapterHarvestable.HarvestAddresses({
            swapper: ProtocolSonic.GOAT_SWAPPER,
            wrappedGas: AssetsSonic.WS
        });

        SiloV2Adapter adapter = new SiloV2Adapter(address(multistrategy), multistrategy.asset(), vault, incentivesController, harvestAddresses, "", "");
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
            assertGt(multistrategy.pricePerShare(), (10 ** IERC20Metadata(asset).decimals()));
        }
    }
}