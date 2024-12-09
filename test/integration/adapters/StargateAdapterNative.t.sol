// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import { Test } from "forge-std/Test.sol";
import { Multistrategy } from "src/infra/multistrategy/Multistrategy.sol";
import { StargateAdapterNative } from "src/infra/multistrategy/adapters/StargateAdapterNative.sol";
import { IStrategyAdapterHarvestable } from "interfaces/infra/multistrategy/IStrategyAdapterHarvestable.sol";
import { StrategyAdapterHarvestable } from "src/abstracts/StrategyAdapterHarvestable.sol";
import { AdapterIntegration } from "./shared/AdapterIntegration.t.sol";
import { AssetsArbitrum } from "@addressbook/AssetsArbitrum.sol";
import { ProtocolArbitrum } from "@addressbook/ProtocolArbitrum.sol";

contract StargateAdapterNativeIntegration is AdapterIntegration {
    function setUp() public override {
        vm.createSelectFork(vm.envString("ARBITRUM_RPC_URL"));
        super.setUp();

        asset = AssetsArbitrum.WETH;
        depositLimit = 10_000 * (10 ** IERC20Metadata(asset).decimals());
        minDeposit = (10 ** IERC20Metadata(asset).decimals() - 2);

        createMultistrategy(asset, depositLimit);
        createStargateAdapterNative();
    }

    function createStargateAdapterNative() public {
        StargateAdapterNative.StargateAddresses memory siloAddresses = StargateAdapterNative.StargateAddresses({
            router: 0xA45B5130f36CDcA45667738e2a258AB09f4A5f7F,
            chef: 0x3da4f8E456AC648c489c286B99Ca37B666be7C4C
        });

        StrategyAdapterHarvestable.HarvestAddresses memory harvestAddresses = StrategyAdapterHarvestable.HarvestAddresses({
            swapper: ProtocolArbitrum.GOAT_SWAPPER,
            weth: AssetsArbitrum.WETH
        });

        vm.prank(users.keeper); adapter = new StargateAdapterNative(address(multistrategy), asset, harvestAddresses, siloAddresses, "", "");
        vm.prank(users.keeper); adapter.enableGuardian(users.guardian);
        vm.prank(users.keeper); IStrategyAdapterHarvestable(address(adapter)).addReward(0x6694340fc020c5E6B96567843da2df01b2CE1eb6);
    }

    function testFuzz_AdapterLifeCycle(uint256 _depositAmount, uint256 _withdrawAmount, uint256 _yieldTime) public {
        _depositAmount = bound(_depositAmount, minDeposit, multistrategy.depositLimit());
        _withdrawAmount = bound(_withdrawAmount, 1, _depositAmount);
        _yieldTime = bound(_yieldTime, 1 hours, 10 * 365 days);

        super.adapterLifeCycle(_depositAmount, _withdrawAmount, _yieldTime);

        uint256 currentBalance = IERC20(asset).balanceOf(users.bob);
        assertGt(currentBalance, _depositAmount);
    }

    function testFuzz_AdapterPanicProcedure(uint256 _depositAmount, uint256 _withdrawAmount, uint256 _yieldTime) public {
        _depositAmount = bound(_depositAmount, minDeposit, multistrategy.depositLimit());
        _withdrawAmount = bound(_withdrawAmount, 1, _depositAmount);
        _yieldTime = bound(_yieldTime, 1 hours, 10 * 365 days);

        super.adapterPanicProcedure(_depositAmount, _withdrawAmount, _yieldTime);

        assertApproxEqAbs(adapter.totalAssets(), 0, 1);
        assertApproxEqAbs(multistrategy.totalAssets(), IERC20(asset).balanceOf(address(multistrategy)), 1);
    }
}