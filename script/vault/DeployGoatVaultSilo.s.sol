// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {GoatVault} from "src/infra/vault/GoatVault.sol";
import {IGoatVaultFactory} from "interfaces/infra/IGoatVaultFactory.sol";
import {IStrategy} from "interfaces/infra/IStrategy.sol";
import {StratFeeManagerInitializable} from "src/infra/strategies/common/StratFeeManagerInitializable.sol";
import {ProtocolArbitrum} from "@addressbook/ProtocolArbitrum.sol";
import {AssetsArbitrum} from "@addressbook/AssetsArbitrum.sol";
import {GoatUniswapV3Buyback} from "src/infra/GoatUniswapV3Buyback.sol";

// Strategy to deploy
import {StrategySiloBorrowableDeposit} from "src/infra/strategies/silo/StrategySiloBorrowableDeposit.sol";

contract DeployGoatVaultSilo is Script {
    string name = "Goat Silo WETH-ETH+";
    string symbol = "gSiloWETH-ETH+";
    uint256 stratApprovalDelay = 21600;

    address native = AssetsArbitrum.WETH;
    address want = AssetsArbitrum.WETH;
    address collateral = 0x95633979ae07b857a5A03BbA349EAE891E27fB5E;
    address silo = 0x1182559e5cf2247e4DdB7a38e28a88ec3825f2BA;

    StratFeeManagerInitializable.CommonAddresses commonAddresses;

    address[] rewards = [AssetsArbitrum.ARB];

    address unirouter = ProtocolArbitrum.GOAT_SWAPPER;
    address keeper = ProtocolArbitrum.TREASURY;
    address strategist = 0xbd297B4f9991FD23f54e14111EE6190C4Fb9F7e1;
    address protocolFeeRecipient = ProtocolArbitrum.GOAT_FEE_BATCH;
    address feeConfig = ProtocolArbitrum.FEE_CONFIG;

    function run() public {
        IGoatVaultFactory vaultFactory = IGoatVaultFactory(
            ProtocolArbitrum.GOAT_VAULT_FACTORY
        );

        vm.startBroadcast();

        GoatVault vault = vaultFactory.cloneVault();
        StrategySiloBorrowableDeposit strategy = new StrategySiloBorrowableDeposit();

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
            native, 
            collateral, 
            silo, 
            rewards, 
            commonAddresses);

        vm.stopBroadcast();

        console.log("Vault:", address(vault));
        console.log("Strategy:", address(strategy));
    }
}
