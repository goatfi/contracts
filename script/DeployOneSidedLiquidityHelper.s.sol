// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { VirtuswapOneSidedLiquidity } from "src/infra/strategies/virtuswap/VirtuswapOneSidedLiquidity.sol";
import { ProtocolArbitrum } from "@addressbook/ProtocolArbitrum.sol";

contract DeployVirtuswapOneSidedLiquidity is Script {
    address virtuswapFactory = 0x389DB0B69e74A816f1367aC081FdF24B5C7C2433;
    address virtuswapRouter = 0xB455da5a32E7E374dB6d1eDfdb86C167DD983f40;

    function run() public {
        vm.startBroadcast();

        VirtuswapOneSidedLiquidity virtuswapOneSidedliquidity = new VirtuswapOneSidedLiquidity(
            ProtocolArbitrum.GOAT_SWAPPER,
            virtuswapFactory,
            virtuswapRouter
        );

        vm.stopBroadcast();

        console.log("VirtuswapOneSidedLiquidity deployed at:", address(virtuswapOneSidedliquidity));
    }
}