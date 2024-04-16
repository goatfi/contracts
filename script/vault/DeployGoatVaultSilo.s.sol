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
import {StrategySilo} from "src/infra/strategies/silo/StrategySilo.sol";
import {IEqbBooster} from "interfaces/equilibria/IEquilibria.sol";

contract DeployGoatVaultEquilibria is Script {
    string name = "Goat Silo WBTC, ETH, USDC.e Market";
    string symbol = "gSWBC,ETH,USDC";
    uint256 stratApprovalDelay = 21600;

    address native = AssetsArbitrum.WETH;
    address want = AssetsArbitrum.USDCe; // USDC
    address collateral = 0xFb6DE7D8Ca3Ec3396bB1Cc53adDEf1F26468055B; // sUSDC-WBTC
    address silo = 0x69eC552BE56E6505703f0C861c40039e5702037A;

    StratFeeManagerInitializable.CommonAddresses commonAddresses;

    address[] rewards = [AssetsArbitrum.ARB, AssetsArbitrum.SILO];

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
        StrategySilo strategy = new StrategySilo();

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
        strategy.initialize(native, collateral, silo, rewards, commonAddresses);

        vm.stopBroadcast();

        console.log("Vault:", address(vault));
        console.log("Strategy:", address(strategy));
    }
}
