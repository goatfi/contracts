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
import { StrategyCurveConvexL2 } from "src/infra/strategies/curve/StrategyCurveConvexL2.sol";

contract DeployGoatVaultCurve is Script {

    string name = "Goat Curve fETH-xETH-WETH";
    string symbol = "gCurvefETH-xETH-WETH";
    uint256 stratApprovalDelay = 21600;

    uint256 pid = 15;
    address native = AssetsArbitrum.WETH;
    address want = 0xF7Fed8Ae0c5B78c19Aadd68b700696933B0Cefd9;
    address depositToken = address(0);
    address rewardPool = ProtocolArbitrum.GOAT_REWARD_POOL;
    address gauge = 0x7AE49935b8BC11023e5b04d86a44055f999fca31;

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
        StrategyCurveConvexL2 strategy = new StrategyCurveConvexL2();

        commonAddresses = StratFeeManagerInitializable.CommonAddresses(
            address(vault),
            unirouter,
            keeper,
            strategist,
            protocolFeeRecipient,
            feeConfig
            );

        vault.initialize(IStrategy(address(strategy)), name, symbol, stratApprovalDelay);
        strategy.initialize(native, want, gauge, pid, depositToken, rewards, commonAddresses);

        vm.stopBroadcast();

        console.log("Vault:", address(vault));
        console.log("Strategy:", address(strategy));
    }
}