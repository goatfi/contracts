// SPDX-License-Identifier: MIT
pragma solidity^0.8.20;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { IMultistrategy } from "interfaces/infra/multistrategy/IMultistrategy.sol";
import { AssetsArbitrum } from "@addressbook/AssetsArbitrum.sol";
import { ProtocolArbitrum } from "@addressbook/ProtocolArbitrum.sol";
import { Multistrategy } from "src/infra/multistrategy/Multistrategy.sol";

contract DeployMultistrategy is Script {
    address TESTING_CUSTODIAN = 0x75cb5d555933fe86E0ac8975A623aCb5CEC13E28;

    address constant ASSET = AssetsArbitrum.USDCe;
    address constant MANAGER = ProtocolArbitrum.TREASURY;
    address constant FEE_RECIPIENT = ProtocolArbitrum.TREASURY;
    string constant NAME = "Yield Chasing Silo USDC";
    string constant SYMBOL = "ycsUSDC";
    address constant GUARDIAN = 0xbd297B4f9991FD23f54e14111EE6190C4Fb9F7e1;
    address constant TIMELOCK = ProtocolArbitrum.TIMELOCK;

    uint256 constant INITIAL_DEPOSIT = 10 * 1e6;

    function run() public { 

        if(IERC20(ASSET).balanceOf(msg.sender) < INITIAL_DEPOSIT) {
            console.log("\u001b[1;31m NOT ENOUGH ASSETS FOR INITIAL DEPOSIT \u001b[0m");
            return;
        }
    
        vm.startBroadcast();

        Multistrategy multistrategy = new Multistrategy(ASSET, TESTING_CUSTODIAN, FEE_RECIPIENT, NAME, SYMBOL);

        IERC20(ASSET).approve(address(multistrategy), INITIAL_DEPOSIT);
        
        // Set the deposit limit
        multistrategy.setDepositLimit(500_000 * 1e6);
        // Deposit some assets to prevent inflation attack
        multistrategy.deposit(INITIAL_DEPOSIT, TESTING_CUSTODIAN);
        // Enable a Guardian
        multistrategy.enableGuardian(GUARDIAN);
        // Transfer ownership to the timelock
        multistrategy.transferOwnership(TESTING_CUSTODIAN);

        vm.stopBroadcast(); 

        console.log("Multistrategy:", address(multistrategy));

        if(multistrategy.totalAssets() == INITIAL_DEPOSIT) {
            console.log("\u001b[1;32m INITIAL DEPOSIT SUCCESSFUL \u001b[0m");
        } else {
            console.log("\u001b[1;31m INITIAL DEPOSIT FRONT-RAN \u001b[0m");
        }
    }
}