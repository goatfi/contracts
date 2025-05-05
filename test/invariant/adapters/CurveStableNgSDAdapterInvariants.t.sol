// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.9.0;

import { Test } from "forge-std/Test.sol";
import { console } from "forge-std/console.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import { AssetsArbitrum, ProtocolArbitrum } from "@addressbook/AddressBook.sol";
import { AdapterInvariantBase } from "./AdapterInvariantBase.t.sol";
import { AdapterHandler } from "./AdapterHandler.t.sol";
import { CurveStableNgSDAdapter } from "src/infra/multistrategy/adapters/CurveStableNgSDAdapter.sol";
import { CurveStableNgSlippageUtility } from "src/infra/utilities/curve/CurveStableNgSlippageUtility.sol";
import { StrategyAdapterHarvestable } from "src/abstracts/StrategyAdapterHarvestable.sol";

contract CurveNgSDTest is AdapterInvariantBase {
    AdapterHandler handler;
    CurveStableNgSDAdapter adapter;
    CurveStableNgSlippageUtility curveUtility;
    address asset = AssetsArbitrum.USDC;
    address curveLP = 0x49b720F1Aab26260BEAec93A7BeB5BF2925b2A8F;
    address sdVault = 0xa8D278db4ca48e7333901b24A83505BB078ecF86;
    address sdRewards = 0xAbf4368d120190B4F111C30C92cc9f8f6a6BE233;
    int128 assetIndex = 0;

    function setUp() public {
        vm.createSelectFork(vm.envString("ARBITRUM_RPC_URL"));
        createUsers();
        curveUtility = new CurveStableNgSlippageUtility();
        multistrategy = createMultistrategy(asset, 1_000_000 * (10 ** IERC20Metadata(asset).decimals()));
        adapter = createAdapter();

        makeInitialDeposit(10 * (10 ** IERC20Metadata(asset).decimals()));
    }

    function createAdapter() public returns (CurveStableNgSDAdapter) {
        StrategyAdapterHarvestable.HarvestAddresses memory harvestAddresses = StrategyAdapterHarvestable.HarvestAddresses({
            swapper: ProtocolArbitrum.GOAT_SWAPPER,
            wrappedGas: AssetsArbitrum.WETH
        });

        CurveStableNgSDAdapter.CurveSNGSDData memory curveData = CurveStableNgSDAdapter.CurveSNGSDData({
            curveLiquidityPool: curveLP,
            sdVault: sdVault,
            sdRewards: sdRewards,
            curveSlippageUtility: address(curveUtility),
            assetIndex: assetIndex
        });

        CurveStableNgSDAdapter _adapter = new CurveStableNgSDAdapter(address(multistrategy), multistrategy.asset(), harvestAddresses, curveData, "", "");
        _adapter.transferOwnership(users.keeper);
        vm.prank(users.keeper); _adapter.enableGuardian(users.guardian);
        vm.prank(users.keeper);
        vm.prank(users.owner); multistrategy.addStrategy(address(_adapter), 10_000, 0, type(uint256).max);

        return _adapter;
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