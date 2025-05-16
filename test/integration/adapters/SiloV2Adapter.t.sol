// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import { Test } from "forge-std/Test.sol";
import { Multistrategy } from "src/infra/multistrategy/Multistrategy.sol";
import { SiloV2Adapter } from "src/infra/multistrategy/adapters/SiloV2Adapter.sol";
import { IStrategyAdapterHarvestable } from "interfaces/infra/multistrategy/IStrategyAdapterHarvestable.sol";
import { StrategyAdapterHarvestable } from "src/abstracts/StrategyAdapterHarvestable.sol";
import { AdapterIntegration } from "./shared/AdapterIntegration.t.sol";
import { AssetsSonic, ProtocolSonic } from "@addressbook/AddressBook.sol";

interface ISiloV2Adapter {
    function setIncentivesController(address _incentivesController) external;
    function incentivesController() external returns (address);
}

contract SiloV2AdapterIntegration is AdapterIntegration {

    function setUp() public override {
        vm.createSelectFork(vm.envString("SONIC_RPC_URL"));
        super.setUp();

        asset = AssetsSonic.USDCe;
        depositLimit = 10_000_000 * (10 ** IERC20Metadata(asset).decimals());
        minDeposit = (10 ** IERC20Metadata(asset).decimals() - 2);
        harvest = false;

        createMultistrategy();
        createSiloAdapter();
    }

    function createSiloAdapter() public {
        address vault = 0x7e88AE5E50474A48deA4c42a634aA7485e7CaA62;
        address incentivesController = address(0);
        StrategyAdapterHarvestable.HarvestAddresses memory harvestAddresses = StrategyAdapterHarvestable.HarvestAddresses({
            swapper: ProtocolSonic.GOAT_SWAPPER,
            wrappedGas: AssetsSonic.WS
        });

        adapter = new SiloV2Adapter(address(multistrategy), multistrategy.asset(), vault, incentivesController, harvestAddresses, "", "");
        adapter.transferOwnership(users.keeper);
        vm.prank(users.keeper); adapter.enableGuardian(users.guardian);
    }

    function testFuzz_AdapterPanicProcedure(uint256 _depositAmount, uint256 _withdrawAmount, uint256 _yieldTime, uint256 _debtRatio) public {
        super.adapterPanicProcedure(_depositAmount, _withdrawAmount, _yieldTime, _debtRatio);

        assertEq(adapter.totalAssets(), 0);
        assertEq(multistrategy.totalAssets(), IERC20(asset).balanceOf(address(multistrategy)));
    }

    function test_SetIncentivesController() public {
        address newIncentivesController = address(0x123456);

        vm.prank(users.keeper); ISiloV2Adapter(address(adapter)).setIncentivesController(newIncentivesController);

        assertEq(ISiloV2Adapter(address(adapter)).incentivesController(), newIncentivesController);
    }

    function test_SetIncentivesController_RevertsForNonKeeper() public {
        address newIncentivesController = address(0x123456);

        vm.expectRevert();
        ISiloV2Adapter(address(adapter)).setIncentivesController(newIncentivesController);
    }
}