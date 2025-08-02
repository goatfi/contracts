// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.9.0;

import { Test } from "forge-std/Test.sol";
import { console } from "forge-std/console.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import { AssetsArbitrum, ProtocolArbitrum } from "@addressbook/AddressBook.sol";
import { AdapterHandler } from "./AdapterHandler.t.sol";
import { AdapterInvariantBase } from "./AdapterInvariantBase.t.sol";
import { ICurveLPBase } from "interfaces/infra/multistrategy/adapters/ICurveLPBase.sol";
import { IStrategyAdapterHarvestable } from "interfaces/infra/multistrategy/IStrategyAdapterHarvestable.sol";
import { StrategyAdapterHarvestable } from "src/abstracts/StrategyAdapterHarvestable.sol";
import { CurveStableNgSDV2Adapter } from "src/infra/multistrategy/adapters/CurveStableNgSDV2Adapter.sol";
import { CurveStableNgSlippageUtility } from "src/infra/utilities/curve/CurveStableNgSlippageUtility.sol";

contract CurveStableNgSDV2AdapterInvariants is AdapterInvariantBase {
    address[] rewards = [AssetsArbitrum.CRV];
    AdapterHandler handler;

    function setUp() public override {
        vm.createSelectFork(vm.envString("ARBITRUM_RPC_URL"));
        asset = AssetsArbitrum.USDT;
        super.setUp();
        
        handler = new AdapterHandler(
            createMultistrategy(asset, 100_000 * (10 ** decimals)), 
            createAdapter(), 
            users,
            false
        );

        makeInitialDeposit(10 * (10 ** decimals));
        targetContract(address(handler));

        vm.prank(users.owner); multistrategy.setSlippageLimit(1);
    }

    function createAdapter() public returns (CurveStableNgSDV2Adapter) {
        StrategyAdapterHarvestable.HarvestAddresses memory harvestAddresses = StrategyAdapterHarvestable.HarvestAddresses({
            swapper: ProtocolArbitrum.GOAT_SWAPPER,
            wrappedGas: AssetsArbitrum.WETH
        });

        CurveStableNgSDV2Adapter.CurveSNGSDV2Data memory curveData = CurveStableNgSDV2Adapter.CurveSNGSDV2Data({
            curveLiquidityPool: 0x49b720F1Aab26260BEAec93A7BeB5BF2925b2A8F,
            sdVault: 0x5E162b4AC251599a218B0C37b4854E33a54fFCa7,
            curveSlippageUtility: address(new CurveStableNgSlippageUtility()),
            assetIndex: 1
        });

        CurveStableNgSDV2Adapter _adapter = new CurveStableNgSDV2Adapter(address(multistrategy), multistrategy.asset(), harvestAddresses, curveData, "", "");
        _adapter.transferOwnership(users.keeper);

        vm.prank(users.owner); multistrategy.addStrategy(address(_adapter), 10_000, 0, type(uint256).max);
        vm.startPrank(users.keeper);
            multistrategy.setStrategyMinDebtDelta(address(_adapter), 1 * (10 ** decimals));
            _adapter.enableGuardian(users.guardian);
            _adapter.setSlippageLimit(5);
            ICurveLPBase(address(_adapter)).setCurveSlippageLimit(0.0005 ether);
            ICurveLPBase(address(_adapter)).setWithdrawBufferPPM(2);
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