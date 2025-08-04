// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { AdapterIntegration } from "./shared/AdapterIntegration.t.sol";
import { AssetsArbitrum, ProtocolArbitrum } from "@addressbook/AddressBook.sol";
import { StrategyAdapterHarvestable } from "src/abstracts/StrategyAdapterHarvestable.sol";
import { CurveLendSDV2Adapter } from "src/infra/multistrategy/adapters/CurveLendSDV2Adapter.sol";
import { IStrategyAdapterHarvestable } from "interfaces/infra/multistrategy/IStrategyAdapterHarvestable.sol";
import { Errors } from "src/infra/libraries/Errors.sol";

contract CurveLendSDV2AdapterIntegration is AdapterIntegration {

    function setUp() public override {
        vm.createSelectFork(vm.envString("ARBITRUM_RPC_URL"));
        asset = AssetsArbitrum.CRVUSD;
        super.setUp();

        depositLimit = 500_000 * (10 ** decimals);
        minDeposit = 10 * (10 ** decimals);
        minDebtDelta = 1 * (10 ** decimals);
        harvest = false;

        createMultistrategy();
        createCurveAdapter();
    }

    function createCurveAdapter() public {
        CurveLendSDV2Adapter.CurveLendSDV2Addresses memory curveAddresses = CurveLendSDV2Adapter.CurveLendSDV2Addresses({
            lendVault: 0xa6C2E6A83D594e862cDB349396856f7FFE9a979B,
            sdVault: 0x17E876675258DeE5A7b2e2e14FCFaB44F867896c
        });
        StrategyAdapterHarvestable.HarvestAddresses memory harvestAddresses = StrategyAdapterHarvestable.HarvestAddresses({
            swapper: ProtocolArbitrum.GOAT_SWAPPER,
            wrappedGas: AssetsArbitrum.WETH
        });

        adapter = new CurveLendSDV2Adapter(address(multistrategy), multistrategy.asset(), harvestAddresses, curveAddresses, "", "");
        adapter.transferOwnership(users.keeper);

        vm.startPrank(users.keeper);
            adapter.enableGuardian(users.guardian);
        vm.stopPrank();
    }

    function test_availableLiquidity() public view {
        uint256 availableLiquidity = adapter.availableLiquidity();
        assertGt(availableLiquidity, 0);
    }

    function testFuzz_AdapterPanicProcedure(uint256 _depositAmount, uint256 _withdrawAmount, uint256 _yieldTime, uint256 _debtRatio) public {
        super.adapterPanicProcedure(_depositAmount, _withdrawAmount, _yieldTime, _debtRatio);

        assertEq(adapter.totalAssets(), 0);
        assertGt(multistrategy.totalAssets(), 0);
    }
}
