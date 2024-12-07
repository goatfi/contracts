// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import { Test } from "forge-std/Test.sol";
import { Multistrategy } from "src/infra/multistrategy/Multistrategy.sol";
import { SiloAdapter } from "src/infra/multistrategy/adapters/SiloAdapter.sol";
import { IStrategyAdapterHarvestable } from "interfaces/infra/multistrategy/IStrategyAdapterHarvestable.sol";
import { StrategyAdapterHarvestable } from "src/abstracts/StrategyAdapterHarvestable.sol";
import { AdapterIntegration } from "./shared/AdapterIntegration.t.sol";
import { AssetsArbitrum } from "@addressbook/AssetsArbitrum.sol";
import { ProtocolArbitrum } from "@addressbook/ProtocolArbitrum.sol";

contract SiloAdapterIntegration is AdapterIntegration {
    SiloAdapter adapter;

    function setUp() public override {
        vm.createSelectFork(vm.envString("ARBITRUM_RPC_URL"));
        super.setUp();

        asset = AssetsArbitrum.WETH;
        depositLimit = 10_000_000 * (10 ** IERC20Metadata(asset).decimals());
        minDeposit = (10 ** IERC20Metadata(asset).decimals() - 2);

        createMultistrategy(asset, depositLimit);
        createSiloAdapter();
    }

    function createSiloAdapter() public {
        SiloAdapter.SiloAddresses memory siloAddresses = SiloAdapter.SiloAddresses({
            silo: 0x1182559e5cf2247e4DdB7a38e28a88ec3825f2BA,
            collateral: 0x95633979ae07b857a5A03BbA349EAE891E27fB5E,
            siloLens: 0xBDb843c7a7e48Dc543424474d7Aa63b61B5D9536,
            siloRewards: 0xbDBBf747402653A5aD6F6B8c49F2e8dCeC37fAcF,
            merklDistributor: 0x3Ef3D8bA38EBe18DB133cEc108f4D14CE00Dd9Ae
        });

        StrategyAdapterHarvestable.HarvestAddresses memory harvestAddresses = StrategyAdapterHarvestable.HarvestAddresses({
            swapper: ProtocolArbitrum.GOAT_SWAPPER,
            weth: AssetsArbitrum.WETH
        });

        vm.prank(users.keeper); adapter = new SiloAdapter(address(multistrategy), asset, harvestAddresses, siloAddresses, "", "");
        vm.prank(users.keeper); adapter.enableGuardian(users.guardian);
        vm.prank(users.keeper); IStrategyAdapterHarvestable(address(adapter)).addReward(AssetsArbitrum.SILO);
    }

    function testFuzz_AdapterLifeCycle(uint256 _depositAmount, uint256 _withdrawAmount, uint256 _yieldTime) public {
        _depositAmount = bound(_depositAmount, minDeposit, multistrategy.depositLimit());
        _withdrawAmount = bound(_withdrawAmount, 1, _depositAmount);
        _yieldTime = bound(_yieldTime, 1 hours, 10 * 365 days);

        deposit(_depositAmount);
        addAdapter(address(adapter));
        requestCredit(address(adapter));
        earnYield(address(adapter), _yieldTime, true);
        setDebtRatio(address(adapter), 5_000);
        withdraw(_withdrawAmount);
        retireAdapter(address(adapter));
        withdrawAll();

        uint256 currentBalance = IERC20(asset).balanceOf(users.bob);
        assertGt(currentBalance, _depositAmount);
    }

    function testFuzz_AdapterPanicProcedure(uint256 _depositAmount, uint256 _withdrawAmount, uint256 _yieldTime) public {
        _depositAmount = bound(_depositAmount, minDeposit, multistrategy.depositLimit());
        _withdrawAmount = bound(_withdrawAmount, 1, _depositAmount);
        _yieldTime = bound(_yieldTime, 0, 10 * 365 days);

        deposit(_depositAmount);
        addAdapter(address(adapter));
        requestCredit(address(adapter));
        earnYield(address(adapter), _yieldTime, true);
        setDebtRatio(address(adapter), 5_000);
        withdraw(_withdrawAmount);

        retireAdapter(address(adapter));
        panicAdapter(address(adapter));
        sendReportPanicked(address(adapter));

        assertApproxEqAbs(adapter.totalAssets(), 0, 1);
        assertApproxEqAbs(multistrategy.totalAssets(), IERC20(asset).balanceOf(address(multistrategy)), 1);
    }
}