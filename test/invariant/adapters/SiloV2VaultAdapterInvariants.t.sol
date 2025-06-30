// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import { console } from "forge-std/console.sol";
import { AdapterInvariantBase } from "./AdapterInvariantBase.t.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import { AdapterHandler } from "./AdapterHandler.t.sol";
import { AssetsSonic, ProtocolSonic } from "@addressbook/AddressBook.sol";
import { Users } from "../../utils/Types.sol";
import { SiloV2VaultAdapter } from "src/infra/multistrategy/adapters/SiloV2VaultAdapter.sol";
import { StrategyAdapterHarvestable } from "src/abstracts/StrategyAdapterHarvestable.sol";


contract SiloV2VaultAdapterInvariants is AdapterInvariantBase {
    AdapterHandler handler;
    bool harvest = true;

    function setUp() public override {
        vm.createSelectFork(vm.envString("SONIC_RPC_URL"));
        asset = AssetsSonic.USDC;
        super.setUp();
        
        handler = new AdapterHandler(
            createMultistrategy(asset, 100_000 * (10 ** decimals)), 
            createAdapter(), 
            users,
            harvest
        );

        makeInitialDeposit(10 * (10 ** decimals));
        targetContract(address(handler));
    }

    function createAdapter() public returns (SiloV2VaultAdapter) {
        address vault = 0xcca902f2d3d265151f123d8ce8FdAc38ba9745ed;

        SiloV2VaultAdapter.SiloV2VaultAddresses memory siloV2Addresses = SiloV2VaultAdapter.SiloV2VaultAddresses({
            incentivesController: 0xfFd019f29b068BCec229Ad352bA8346814BCFf72,
            idleMarket: 0x54EbD8DE6e3D325164046cdcDB5d4Cf4Fe6BaE2b
        });

        StrategyAdapterHarvestable.HarvestAddresses memory harvestAddresses = StrategyAdapterHarvestable.HarvestAddresses({
            swapper: ProtocolSonic.GOAT_SWAPPER,
            wrappedGas: AssetsSonic.WS
        });

        SiloV2VaultAdapter adapter = new SiloV2VaultAdapter(address(multistrategy), multistrategy.asset(), vault, siloV2Addresses, harvestAddresses, "", "");
        adapter.transferOwnership(users.keeper);
        vm.prank(users.keeper); adapter.enableGuardian(users.guardian);
        vm.prank(users.owner); multistrategy.addStrategy(address(adapter), 10_000, 0, type(uint256).max);

        return adapter;
    }

    function invariant_pricePerShare() public view {
        console.log("Deposited:", handler.ghost_deposited());
        console.log("Withdrawn:", handler.ghost_withdrawn());
        console.log("Yield Time:", handler.ghost_yieldTime());

        address adapter = multistrategy.getWithdrawOrder()[0];
        uint256 totalGain = multistrategy.getStrategyParameters(address(adapter)).totalGain;
        console.log("Total Gain", totalGain);
        console.log("PPS:", multistrategy.pricePerShare());

        if (handler.ghost_yieldTime() > 0) {
            assertGe(multistrategy.pricePerShare(), (10 ** decimals));
        }
    }
}