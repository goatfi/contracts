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

// Strategy to deploy
import { StrategyVirtuswap } from "src/infra/strategies/virtuswap/StrategyVirtuswap.sol";

contract DeployGoatVaultVirtuswap is Script {

    string name = "Goat Virtuswap tBTC-WETH";
    string symbol = "gVirtuswaptBTC-WETH";
    uint256 stratApprovalDelay = 21600;

    address native = AssetsArbitrum.WETH;
    address want = 0x8431aAaa1bB7BD11d4740F19a0306e00b7eDB817;
    address depositToken = address(0);
    address rewardPool = ProtocolArbitrum.GOAT_REWARD_POOL;

    address[] rewards = [AssetsArbitrum.CRV, AssetsArbitrum.CRVUSD, AssetsArbitrum.ARB];
    
    StratFeeManagerInitializable.CommonAddresses commonAddresses;

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
        StrategyVirtuswap strategy = new StrategyVirtuswap();

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
            want, 
            depositToken, 
            rewards, 
            commonAddresses
            );

        vm.stopBroadcast();

        console.log("Vault:", address(vault));
        console.log("Strategy:", address(strategy));
    }
}