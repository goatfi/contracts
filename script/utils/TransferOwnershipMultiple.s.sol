// SPDX-License-Identifier: MIT
pragma solidity^0.8.20;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { ProtocolArbitrum } from "@addressbook/ProtocolArbitrum.sol";

interface IOwnable {
    function transferOwnership(address newOwner) external;
    function owner() external view returns (address);
}

contract TransferOwnershipMultiple is Script {
    address[] contracts = [
        ProtocolArbitrum.GOAT_REWARD_POOL,
        ProtocolArbitrum.GOAT_FEE_BATCH,
        ProtocolArbitrum.FEE_CONFIG,
        0x3475F10D46ABbb2e0176ca1b00949990B496B00c, //Vault crvUSD-FRAX
        0x64318B0882B6595AA662751eE5966ae4019cac23, //Strategy crvUSD-FRAX
        0xD72c55c0f51F208A1ce905C7c24E5c3364335930, //Vault crvUSD-USDC
        0xC500a6cD941c43B345E08261146C942EEE1Da156, //Strategy crvUSD-USDC
        0x420359d4f7cd4ec1d8D8a2225810ADD194405dA0, //Vault crvUSD-USDT
        0x0CBb38290929c0a9755d6E6E69F41Ac7465C3Be8, //Strategy crvUSD-USDT
        0x306559074016481D432b0067cA2c583d6bdE8b84, //Vault crvUSD-USDCe
        0xcF9619C9dafF4CA6990fb9f706C8bb3de640a9B5 //Strategy crvUSD-USDCe
    ];

    function run() public {
        uint privateKey = vm.envUint("DEPLOY_PK");
        address account = vm.addr(privateKey);

        console.log("Account", account);

        vm.startBroadcast(privateKey);

        for (uint i = 0; i < contracts.length; i++) {
            IOwnable(contracts[i]).transferOwnership(ProtocolArbitrum.TIMELOCK);
            console.log("Contract", contracts[i], "owner is", IOwnable(contracts[i]).owner());
        }

        vm.stopBroadcast();
    }
}