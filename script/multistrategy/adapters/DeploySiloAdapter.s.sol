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
    string name = "Goat Silo WETH-ezETH";                                //FIXME:
    string symbol = "gsWETH-ezETH";                                     //FIXME:
    uint256 stratApprovalDelay = 21600;
    address collateral = 0xe7F05eFb2A1572e96428bbfE5D1e4c9E3689b2ec;    //FIXME:
    address silo = 0x4a2bd8dcc2539e19cb97DF98EF5afC4d069d9e4C;          //FIXME:
    address siloLens = 0xBDb843c7a7e48Dc543424474d7Aa63b61B5D9536;      //FIXME:
    address siloRewards = 0xbDBBf747402653A5aD6F6B8c49F2e8dCeC37fAcF;   //FIXME:

    uint256 constant INITIAL_DEPOSIT = 0.001 ether;

    StratFeeManagerInitializable.CommonAddresses commonAddresses;
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
    address constant MULTISTRATEGY = 0x878b7897C60fA51c2A7bfBdd4E3cB5708D9eEE43;        //FIXME:
    address constant ASSET = AssetsArbitrum.WETH;
    address constant GUARDIAN = 0xbd297B4f9991FD23f54e14111EE6190C4Fb9F7e1;
    address constant TESTING_CUSTODIAN = 0x75cb5d555933fe86E0ac8975A623aCb5CEC13E28;    //FIXME:
    string constant NAME = "Goat Protocol Silo ezETH";                                  //FIXME:
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

        vault.initialize(
            IStrategy(address(strategy)),
            name,
            symbol,
            stratApprovalDelay
        );

        strategy.initialize(
            ASSET, 
            collateral, 
            silo,
            siloLens,
            siloRewards,
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