// SPDX-License-Identifier: MIT
pragma solidity^0.8.20;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { GoatVault } from "src/infra/vault/GoatVault.sol";
import { IGoatVaultFactory } from "interfaces/infra/IGoatVaultFactory.sol";
import { IStrategy } from "interfaces/infra/IStrategy.sol";
import { StratFeeManagerInitializable } from "src/infra/strategies/common/StratFeeManagerInitializable.sol";
import { StrategySiloBorrowableDeposit } from "src/infra/strategies/silo/StrategySiloBorrowableDeposit.sol";
import { GoatProtocolStrategyAdapter } from "src/infra/multistrategy/adapters/GoatProtocolAdapter.sol";
import { AssetsArbitrum } from "@addressbook/AssetsArbitrum.sol";
import { ProtocolArbitrum } from "@addressbook/ProtocolArbitrum.sol";

contract DeploySiloAdapter is Script {
    /////////////////////////////////////////////////////////
    //                    VAULT CONFIG                     //
    /////////////////////////////////////////////////////////
    string name = "Goat Silo USDC-wstETH";                                //FIXME:
    string symbol = "gsUSDC-wstETH";                                     //FIXME:
    uint256 stratApprovalDelay = 21600;
    address collateral = 0x713fc13CaAB628F116Bc34961f22a6B44aD27668;    //FIXME:
    address silo = 0xA8897b4552c075e884BDB8e7b704eB10DB29BF0D;          //FIXME:
    address siloLens = 0xBDb843c7a7e48Dc543424474d7Aa63b61B5D9536;
    address siloRewards = 0xbDBBf747402653A5aD6F6B8c49F2e8dCeC37fAcF;
    address merklDistributor = 0x3Ef3D8bA38EBe18DB133cEc108f4D14CE00Dd9Ae;
    address merklOperator = 0x1017417B0EE0a96Ee7230e534A83d35d28613B78;

    uint256 constant INITIAL_DEPOSIT = 1 * 1e6;

    StratFeeManagerInitializable.CommonAddresses commonAddresses;
    StrategySiloBorrowableDeposit.SiloAddresses siloAddresses;

    address[] rewards = [AssetsArbitrum.SILO];

    address unirouter = ProtocolArbitrum.GOAT_SWAPPER;
    address keeper = ProtocolArbitrum.TREASURY;
    address strategist = 0xbd297B4f9991FD23f54e14111EE6190C4Fb9F7e1;
    address protocolFeeRecipient = ProtocolArbitrum.GOAT_FEE_BATCH;
    address feeConfig = ProtocolArbitrum.FEE_CONFIG;
    address timelock = ProtocolArbitrum.TIMELOCK;

    /////////////////////////////////////////////////////////
    //                   ADAPTER CONFIG                    //
    /////////////////////////////////////////////////////////
    address constant MULTISTRATEGY = 0x8a1eF3066553275829d1c0F64EE8D5871D5ce9d3;        //FIXME:
    address constant ASSET = AssetsArbitrum.USDCe;
    address constant GUARDIAN = 0xbd297B4f9991FD23f54e14111EE6190C4Fb9F7e1;
    address constant TESTING_CUSTODIAN = 0x75cb5d555933fe86E0ac8975A623aCb5CEC13E28;    //FIXME:
    string constant NAME = "Goat Protocol Silo wstETH";                                  //FIXME:
    string constant ID = "GP";

    function run() public { 
        IGoatVaultFactory vaultFactory = IGoatVaultFactory(
            ProtocolArbitrum.GOAT_VAULT_FACTORY
        );

        vm.startBroadcast();

        if(IERC20(ASSET).balanceOf(msg.sender) < INITIAL_DEPOSIT) {
            console.log("\u001b[1;31m NOT ENOUGH ASSETS FOR INITIAL DEPOSIT \u001b[0m");
            return;
        }

        /////////////////////////////////////////////////////////
        //                   VAULT DEPLOYMENT                  //
        /////////////////////////////////////////////////////////

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

        siloAddresses = StrategySiloBorrowableDeposit.SiloAddresses({
            collateral: collateral,
            silo: silo,
            siloLens: siloLens,
            siloRewards: siloRewards
        });

        vault.initialize(
            IStrategy(address(strategy)),
            name,
            symbol,
            stratApprovalDelay
        );

        strategy.initialize(
            ASSET, 
            siloAddresses,
            merklDistributor,
            rewards,
            commonAddresses
        );

        /////////////////////////////////////////////////////////
        //                    VAULT TESTING                    //
        /////////////////////////////////////////////////////////

        IERC20(ASSET).approve(address(vault), INITIAL_DEPOSIT);
        vault.deposit(INITIAL_DEPOSIT);

        strategy.panic();
        strategy.unpause();
        strategy.harvest();
        strategy.toggleMerklOperator(merklOperator);

        vault.transferOwnership(timelock);
        strategy.transferOwnership(timelock);

        /////////////////////////////////////////////////////////
        //                 ADAPTER DEPLOYMENT                  //
        /////////////////////////////////////////////////////////

        GoatProtocolStrategyAdapter adapter = new GoatProtocolStrategyAdapter(MULTISTRATEGY, ASSET, address(vault), NAME, ID);
        adapter.enableGuardian(GUARDIAN);
        adapter.transferOwnership(TESTING_CUSTODIAN);

        vm.stopBroadcast();

        console.log("Vault:", address(vault));
        console.log("Strategy:", address(strategy));
        console.log("Goat Protocol Adapter:", address(adapter));
    } 
}