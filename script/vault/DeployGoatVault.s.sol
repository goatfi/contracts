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
import { StakedGOAStrategy } from "src/infra/strategies/goat/StakedGOAStrategy.sol";

contract DeployGoatVault is Script {

    string name = "Wrapped Staked GOA";
    string symbol = "wstGOA";
    uint256 stratApprovalDelay = 21600;

    address native = AssetsArbitrum.WETH;
    address want = AssetsArbitrum.GOA;
    address rewardPool = ProtocolArbitrum.GOAT_REWARD_POOL;
    
    StratFeeManagerInitializable.CommonAddresses commonAddresses;

    address unirouter = 0x62Fc95FBa4b802aC13017aAa65cA62FfcE6DF0eA;
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
        StakedGOAStrategy strategy = new StakedGOAStrategy();
        GoatUniswapV3Buyback buyback = new GoatUniswapV3Buyback(address(strategy));

        commonAddresses = StratFeeManagerInitializable.CommonAddresses(
            address(vault),
            address(buyback),
            keeper,
            strategist,
            protocolFeeRecipient,
            feeConfig
            );

        vault.initialize(IStrategy(address(strategy)), name, symbol, stratApprovalDelay);
        strategy.initialize(want, native, rewardPool, commonAddresses);
        strategy.setStratFeeId(1);

        vm.stopBroadcast();

        console.log("Vault:", address(vault));
        console.log("Strategy:", address(strategy));
    }
}