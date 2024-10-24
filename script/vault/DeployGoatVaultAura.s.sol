// SPDX-License-Identifier: MIT
pragma solidity^0.8.20;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { GoatVault } from "src/infra/vault/GoatVault.sol";
import { IGoatVaultFactory } from "interfaces/infra/IGoatVaultFactory.sol";
import { IStrategy } from "interfaces/infra/IStrategy.sol";
import { StratFeeManagerInitializable } from "src/infra/strategies/common/StratFeeManagerInitializable.sol";
import { ProtocolArbitrum } from "@addressbook/ProtocolArbitrum.sol";
import { AssetsArbitrum } from "@addressbook/AssetsArbitrum.sol";

// Strategy to deploy
import { StrategyAura } from "src/infra/strategies/aura/StrategyAura.sol";

contract DeployGoatVaultAura is Script {
    string name = "Goat Aura STAR-USDC";
    string symbol = "gASTAR-USDC";
    uint256 stratApprovalDelay = 21600;

    uint256 pid = 30;
    address native = AssetsArbitrum.WETH;
    address depositToken = AssetsArbitrum.USDC;

    address[] rewards = [
        AssetsArbitrum.AURA,
        AssetsArbitrum.BAL,
        AssetsArbitrum.ARB
    ];

    StratFeeManagerInitializable.CommonAddresses commonAddresses;

    address unirouter = ProtocolArbitrum.GOAT_SWAPPER;
    address keeper = ProtocolArbitrum.TREASURY;
    address strategist = 0xbd297B4f9991FD23f54e14111EE6190C4Fb9F7e1;
    address protocolFeeRecipient = ProtocolArbitrum.GOAT_FEE_BATCH;
    address feeConfig = ProtocolArbitrum.FEE_CONFIG;

    function run() public {
        uint deployer_privateKey = vm.envUint("DEPLOY_PK");
        address deployer = vm.addr(deployer_privateKey);
        IGoatVaultFactory vaultFactory = IGoatVaultFactory(
            ProtocolArbitrum.GOAT_VAULT_FACTORY
        );

        console.log("Deployer", deployer);

        vm.startBroadcast(deployer_privateKey);

        GoatVault vault = vaultFactory.cloneVault();
        StrategyAura strategy = new StrategyAura();

        commonAddresses = StratFeeManagerInitializable.CommonAddresses(
            address(vault),
            unirouter,
            keeper,
            strategist,
            protocolFeeRecipient,
            feeConfig
        );

        vault.initialize(
            IStrategy(address(strategy)),
            name,
            symbol,
            stratApprovalDelay
        );

        strategy.initialize(
            pid,
            native,
            depositToken,
            rewards,
            commonAddresses
        );

        vm.stopBroadcast();

        console.log("Vault:", address(vault));
        console.log("Strategy:", address(strategy));
    }
}
