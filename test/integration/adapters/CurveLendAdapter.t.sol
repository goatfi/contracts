// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { AdapterIntegration } from "./shared/AdapterIntegration.t.sol";
import { AssetsArbitrum, ProtocolArbitrum } from "@addressbook/AddressBook.sol";
import { StrategyAdapterHarvestable } from "src/abstracts/StrategyAdapterHarvestable.sol";
import { CurveLendAdapter } from "src/infra/multistrategy/adapters/CurveLendAdapter.sol";
import { IStrategyAdapterHarvestable } from "interfaces/infra/multistrategy/IStrategyAdapterHarvestable.sol";
import { Errors } from "src/infra/libraries/Errors.sol";

contract CurveLendAdapterIntegration is AdapterIntegration {

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
        CurveLendAdapter.CurveLendAddresses memory curveAddresses = CurveLendAdapter.CurveLendAddresses({
            vault: 0xe07f1151887b8FDC6800f737252f6b91b46b5865,
            gauge: address(0),
            gaugeFactory: 0xabC000d88f23Bb45525E447528DBF656A9D55bf5
        });
        StrategyAdapterHarvestable.HarvestAddresses memory harvestAddresses = StrategyAdapterHarvestable.HarvestAddresses({
            swapper: ProtocolArbitrum.GOAT_SWAPPER,
            wrappedGas: AssetsArbitrum.WETH
        });

        adapter = new CurveLendAdapter(address(multistrategy), multistrategy.asset(), harvestAddresses, curveAddresses, "", "");
        adapter.transferOwnership(users.keeper);

        vm.startPrank(users.keeper);
            adapter.enableGuardian(users.guardian);
        vm.stopPrank();
    }

    function testFuzz_AdapterPanicProcedure(uint256 _depositAmount, uint256 _withdrawAmount, uint256 _yieldTime, uint256 _debtRatio) public {
        super.adapterPanicProcedure(_depositAmount, _withdrawAmount, _yieldTime, _debtRatio);

        assertEq(adapter.totalAssets(), 0);
        assertGt(multistrategy.totalAssets(), 0);
    }
}
