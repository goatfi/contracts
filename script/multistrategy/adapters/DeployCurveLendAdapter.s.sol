// SPDX-License-Identifier: MIT
pragma solidity^0.8.20;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import { ICurveGaugeFactory } from "interfaces/curve/ICurveGaugeFactory.sol";
import { ICurveGauge } from "interfaces/curve/ICurveGauge.sol";
import { CurveLendAdapter } from "src/infra/multistrategy/adapters/CurveLendAdapter.sol";
import { StrategyAdapterHarvestable } from "src/abstracts/StrategyAdapterHarvestable.sol";
import { Addressbook } from "@addressbook/AddressBook.sol";

/// @title Deploys a Curve Lend Adapter
contract DeployCurveLendAdapter is Script {
    Addressbook addressbook = new Addressbook();

    function run(
        address multistrategy, 
        string memory name, 
        address curve_lend_vault,
        address[] memory rewards
    ) public {

        require(multistrategy != address(0), "Multistrategy cannot be zero address");

        address asset = IERC4626(multistrategy).asset();
        address manager = addressbook.getManager(block.chainid);
        address guardian = addressbook.getGuardian(block.chainid);
        address gauge_factory = getGaugeFactory(block.chainid);
        address gauge = ICurveGaugeFactory(gauge_factory).get_gauge_from_lp_token(curve_lend_vault);

        require(ICurveGaugeFactory(gauge_factory).is_valid_gauge(gauge), "Gauge not valid");
        require(curve_lend_vault == ICurveGauge(gauge).lp_token(), "Gauge LP token missmatch");

        StrategyAdapterHarvestable.HarvestAddresses memory harvestAddresses = StrategyAdapterHarvestable.HarvestAddresses({
            swapper: addressbook.getGoatSwapper(block.chainid),
            wrappedGas: addressbook.getWrappedGas(block.chainid)
        });

        CurveLendAdapter.CurveLendAddresses memory crvLendSDAddresses = CurveLendAdapter.CurveLendAddresses({
            vault: curve_lend_vault,
            gauge: gauge,
            gaugeFactory: gauge_factory
        });

        vm.startBroadcast();

        CurveLendAdapter adapter = new CurveLendAdapter(multistrategy, asset, harvestAddresses, crvLendSDAddresses, name, "CRV-LEND");

        for(uint i = 0; i < rewards.length; ++i) {
            adapter.addReward(rewards[i]);
        }

        adapter.enableGuardian(guardian);
        adapter.transferOwnership(manager);

        vm.stopBroadcast();
    }

    function getGaugeFactory(uint256 chainId) public pure returns (address) {
        if (chainId == 42161) return 0xabC000d88f23Bb45525E447528DBF656A9D55bf5; // Arbitrum
        revert("Unsupported network");
    }
}