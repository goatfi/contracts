// SPDX-License-Identifier: MIT
pragma solidity^0.8.20;

import { DeployAdapterBase } from "../../DeployAdapterBase.sol";
import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import { ISiloV2Vault } from "interfaces/silo/ISiloV2Vault.sol";
import { ISiloV2IncetivesModule } from "interfaces/silo/ISiloV2IncetivesModule.sol";
import { ISiloV2IncentivesController } from "interfaces/silo/ISiloV2IncentivesController.sol";
import { ISiloV2IdleMarket } from "interfaces/silo/ISiloV2IdleMarket.sol";
import { SiloV2VaultAdapter } from "src/infra/multistrategy/adapters/SiloV2VaultAdapter.sol";
import { StrategyAdapterHarvestable } from "src/abstracts/StrategyAdapterHarvestable.sol";

/// @title Deploys a SiloV2 Curated Vault Adapter
contract DeploySiloV2VaultAdapter is DeployAdapterBase {
    function run(
        address multistrategy,
        string memory name,
        address silo_vault,
        address[] memory rewards
    ) public {

        address asset = IERC4626(multistrategy).asset();
        address manager = addressbook.getManager(block.chainid);
        address guardian = addressbook.getGuardian(block.chainid);
        address incentivesController = getIncentivesController(silo_vault);
        address idleMarket = getIdleMarket(silo_vault);

        _isERC4626(silo_vault, asset);
        _verifyRewards(rewards, asset);
        require(silo_vault == ISiloV2IncentivesController(incentivesController).NOTIFIER(), "Incentives Controller missmatch");
        require(silo_vault == ISiloV2IdleMarket(idleMarket).ONLY_DEPOSITOR(), "Idle Market Missmatch");

        StrategyAdapterHarvestable.HarvestAddresses memory harvestAddresses = StrategyAdapterHarvestable.HarvestAddresses({
            swapper: addressbook.getGoatSwapper(block.chainid),
            wrappedGas: addressbook.getWrappedGas(block.chainid)
        });
        SiloV2VaultAdapter.SiloV2VaultAddresses memory siloV2Addresses = SiloV2VaultAdapter.SiloV2VaultAddresses({
            incentivesController: incentivesController,
            idleMarket: idleMarket
        });

        vm.startBroadcast();

        SiloV2VaultAdapter adapter = new SiloV2VaultAdapter(multistrategy, asset, silo_vault, siloV2Addresses, harvestAddresses, name, "SILO-V2-VAULT");

        for(uint i = 0; i < rewards.length; ++i) {
            adapter.addReward(rewards[i]);
        }

        adapter.enableGuardian(guardian);
        adapter.transferOwnership(manager);

        vm.stopBroadcast();

        _postDeploymentCheck(multistrategy, address(adapter));
    }

    function getIncentivesController(address siloVault) private view returns (address) {
        address incentivesModule = ISiloV2Vault(siloVault).INCENTIVES_MODULE();
        address[] memory notificactionReceivers = ISiloV2IncetivesModule(incentivesModule).getNotificationReceivers();
        return notificactionReceivers[0];
    }

    function getIdleMarket(address siloVault) private view returns (address) {
        uint256 withdrawQueueLength = ISiloV2Vault(siloVault).withdrawQueueLength();
        for(uint256 i = 0; i < withdrawQueueLength; ++i) {
            address market = ISiloV2Vault(siloVault).withdrawQueue(i);
            try ISiloV2IdleMarket(market).ONLY_DEPOSITOR() returns (address) {
                return market;
            } catch  {}
        }
        revert("No idle market");
    }
}