// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.9.0;

import { Test } from "forge-std/Test.sol";
import { console } from "forge-std/console.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import { AssetsArbitrum, ProtocolArbitrum } from "@addressbook/AddressBook.sol";
import { AdapterHandler } from "./AdapterHandler.t.sol";
import { AdapterInvariantBase } from "./AdapterInvariantBase.t.sol";
import { ICurveStableNgSDAdapter } from "interfaces/infra/multistrategy/adapters/ICurveStableNgSDAdapter.sol";
import { IStrategyAdapterHarvestable } from "interfaces/infra/multistrategy/IStrategyAdapterHarvestable.sol";
import { StrategyAdapterHarvestable } from "src/abstracts/StrategyAdapterHarvestable.sol";
import { CurveStableNgSDAdapter } from "src/infra/multistrategy/adapters/CurveStableNgSDAdapter.sol";
import { CurveStableNgSlippageUtility } from "src/infra/utilities/curve/CurveStableNgSlippageUtility.sol";

contract CurveStableNgSDInvariants is AdapterInvariantBase {
    address[] rewards = [AssetsArbitrum.CRV];
    AdapterHandler handler;

    function setUp() public override {
        vm.createSelectFork(vm.envString("ARBITRUM_RPC_URL"));
        asset = AssetsArbitrum.USDC;
        super.setUp();
        
        handler = new AdapterHandler(
            createMultistrategy(asset, 1_000_000 * (10 ** decimals)), 
            createAdapter(), 
            users,
            true
        );

        makeInitialDeposit(10 * (10 ** decimals));
        targetContract(address(handler));

        vm.prank(users.owner); multistrategy.setSlippageLimit(1);
    }

    function createAdapter() public returns (CurveStableNgSDAdapter) {
        StrategyAdapterHarvestable.HarvestAddresses memory harvestAddresses = StrategyAdapterHarvestable.HarvestAddresses({
            swapper: ProtocolArbitrum.GOAT_SWAPPER,
            wrappedGas: AssetsArbitrum.WETH
        });

        CurveStableNgSDAdapter.CurveSNGSDData memory curveData = CurveStableNgSDAdapter.CurveSNGSDData({
            curveLiquidityPool: 0x49b720F1Aab26260BEAec93A7BeB5BF2925b2A8F,
            sdVault: 0xa8D278db4ca48e7333901b24A83505BB078ecF86,
            sdRewards: 0xAbf4368d120190B4F111C30C92cc9f8f6a6BE233,
            curveSlippageUtility: address(new CurveStableNgSlippageUtility()),
            assetIndex: 0
        });

        CurveStableNgSDAdapter _adapter = new CurveStableNgSDAdapter(address(multistrategy), multistrategy.asset(), harvestAddresses, curveData, "", "");
        _adapter.transferOwnership(users.keeper);

        vm.prank(users.owner); multistrategy.addStrategy(address(_adapter), 10_000, 0, type(uint256).max);
        vm.startPrank(users.keeper);
            multistrategy.setStrategyMinDebtDelta(address(_adapter), 1 * (10 ** decimals));
            _adapter.enableGuardian(users.guardian);
            _adapter.setSlippageLimit(1);
            ICurveStableNgSDAdapter(address(_adapter)).setCurveSlippageLimit(0.01 ether);
            ICurveStableNgSDAdapter(address(_adapter)).setBufferPPM(2);
            for(uint i = 0; i < rewards.length; ++i) {
                _adapter.addReward(rewards[i]);
            }
        vm.stopPrank();

        return _adapter;
    }

    function invariant_pricePerShare() public view {
        console.log("Deposited:", handler.ghost_deposited());
        console.log("Withdrawn:", handler.ghost_withdrawn());
        console.log("Yield Time:", handler.ghost_yieldTime());

        if(handler.ghost_yieldTime() > 0 && handler.ghost_deposited() > 0) {
            assertGt(multistrategy.pricePerShare(), 0);
        }
    }
}