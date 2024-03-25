// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { GoatVault } from "src/infra/vault/GoatVault.sol";
import { IGoatVaultFactory } from "interfaces/infra/IGoatVaultFactory.sol";
import { IStrategy } from "interfaces/infra/IStrategy.sol";
import { StratFeeManagerInitializable } from "src/infra/strategies/common/StratFeeManagerInitializable.sol";
import { ProtocolArbitrum } from "@addressbook/ProtocolArbitrum.sol";
import { AssetsArbitrum } from "@addressbook/AssetsArbitrum.sol";
import { GoatUniswapV3Buyback } from "src/infra/GoatUniswapV3Buyback.sol";

// Strategy to deploy
import { StrategyEquilibria } from "src/infra/strategies/equilibria/StrategyEquilibria.sol";
import { IEqbBooster } from "interfaces/equilibria/IEquilibria.sol";

contract DeployGoatVaultEquilibria is Script {

    string name = "Goat Equilibria ezETH 27JUN24";
    string symbol = "gEqb-ezETH-27JUN24";
    uint256 stratApprovalDelay = 21600;

    uint256 pid = 21;
    address native = AssetsArbitrum.WETH;
    address depositToken = AssetsArbitrum.WETH;
    address want = 0x60712e3C9136CF411C561b4E948d4d26637561e7; //Pendle Market
    address rewardPool = ProtocolArbitrum.GOAT_REWARD_POOL;
    address booster = 0x4D32C8Ff2fACC771eC7Efc70d6A8468bC30C26bF;
    
    StratFeeManagerInitializable.CommonAddresses commonAddresses;

    address[] rewards = [AssetsArbitrum.ARB, AssetsArbitrum.PENDLE, AssetsArbitrum.EQB];

    address unirouter = ProtocolArbitrum.GOAT_SWAPPER;
    address keeper = ProtocolArbitrum.TREASURY;
    address strategist = 0xbd297B4f9991FD23f54e14111EE6190C4Fb9F7e1;
    address protocolFeeRecipient = ProtocolArbitrum.GOAT_FEE_BATCH;
    address feeConfig = ProtocolArbitrum.FEE_CONFIG;

    function run() public {
        uint deployer_privateKey = vm.envUint("DEPLOY_PK");
        address deployer = vm.addr(deployer_privateKey);
        IGoatVaultFactory vaultFactory = IGoatVaultFactory(ProtocolArbitrum.GOAT_VAULT_FACTORY);

        console.log("Deployer", deployer);

        vm.startBroadcast(deployer_privateKey);

        GoatVault vault = vaultFactory.cloneVault();
        StrategyEquilibria strategy = new StrategyEquilibria();

        commonAddresses = StratFeeManagerInitializable.CommonAddresses(
            address(vault),
            unirouter,
            keeper,
            strategist,
            protocolFeeRecipient,
            feeConfig
            );

        vault.initialize(IStrategy(address(strategy)), name, symbol, stratApprovalDelay);
        strategy.initialize(native, IEqbBooster(booster), pid, depositToken, rewards, commonAddresses);

        vm.stopBroadcast();

        console.log("Vault:", address(vault));
        console.log("Strategy:", address(strategy));
    }
}