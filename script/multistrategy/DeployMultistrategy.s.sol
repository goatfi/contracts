// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { IMultistrategy } from "interfaces/infra/multistrategy/IMultistrategy.sol";
import { AssetsArbitrum } from "@addressbook/AssetsArbitrum.sol";
import { ProtocolArbitrum } from "@addressbook/ProtocolArbitrum.sol";
import { Multistrategy } from "src/infra/multistrategy/Multistrategy.sol";

contract DeployMultistrategy is Script {

    address constant REIKO = 0xbd297B4f9991FD23f54e14111EE6190C4Fb9F7e1;

    address constant ASSET = AssetsArbitrum.WETH;
    address constant MANAGER = ProtocolArbitrum.TREASURY;
    address constant FEE_RECIPIENT = ProtocolArbitrum.GOAT_FEE_BATCH;
    string constant NAME = "alpha siloWETH";
    string constant SYMBOL = "aSWETH";

    function run() public { 
        uint64 nonce;
    
        vm.startBroadcast();
        nonce = vm.getNonce(msg.sender);

        address preComputedMultistrategy = computeCreateAddress(msg.sender, nonce + 1);

        IERC20(ASSET).approve(preComputedMultistrategy, 0.01 ether);
        Multistrategy multistrategy = new Multistrategy(ASSET, MANAGER, FEE_RECIPIENT, NAME, SYMBOL);

        if(address(multistrategy) == preComputedMultistrategy) {
            // Enable REIKO as guardian
            multistrategy.enableGuardian(REIKO);
            // Set the deposit limit to 1 ETH
            multistrategy.setDepositLimit(1 ether);
            // Set performance fee to 5%
            multistrategy.setPerformanceFee(1000);
            // Transfer ownership to the treasury
            multistrategy.transferOwnership(MANAGER);

            console.log("Multistrategy:", address(multistrategy));
        }

        vm.stopBroadcast(); 
    }
}