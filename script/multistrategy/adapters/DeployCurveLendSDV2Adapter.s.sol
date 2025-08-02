// SPDX-License-Identifier: MIT
pragma solidity^0.8.20;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { CurveLendSDV2Adapter } from "src/infra/multistrategy/adapters/CurveLendSDV2Adapter.sol";
import { AssetsArbitrum, ProtocolArbitrum, VaultsArbitrum } from "@addressbook/AddressBook.sol";
import { StrategyAdapterHarvestable } from "src/abstracts/StrategyAdapterHarvestable.sol";

contract DeployCurveLendSDV2Adapter is Script {
    address[] rewards = [AssetsArbitrum.CRV];

    address constant CRV_LEND_VAULT = 0xa6C2E6A83D594e862cDB349396856f7FFE9a979B;
    address constant SD_VAULT = 0x17E876675258DeE5A7b2e2e14FCFaB44F867896c;

    /////////////////////////////////////////////////////////
    //                   ADAPTER CONFIG                    //
    /////////////////////////////////////////////////////////
    address constant MULTISTRATEGY = VaultsArbitrum.ycCRVUSD;
    address constant ASSET = AssetsArbitrum.CRVUSD;
    address constant GUARDIAN = 0xbd297B4f9991FD23f54e14111EE6190C4Fb9F7e1;
    string constant NAME = "Stake DAO Curve Lend ARB";                            //FIXME:
    string constant ID = "CRV-LEND-SDV2";

    StrategyAdapterHarvestable.HarvestAddresses harvestAddresses = StrategyAdapterHarvestable.HarvestAddresses({
        swapper: ProtocolArbitrum.GOAT_SWAPPER,
        wrappedGas: AssetsArbitrum.WETH
    });

    CurveLendSDV2Adapter.CurveLendSDV2Addresses crvLendSDV2Addresses = CurveLendSDV2Adapter.CurveLendSDV2Addresses({
        lendVault: CRV_LEND_VAULT,
        sdVault: SD_VAULT
    });

    function run() public {

        /////////////////////////////////////////////////////////
        //                 ADAPTER DEPLOYMENT                  //
        /////////////////////////////////////////////////////////

        vm.startBroadcast();

        CurveLendSDV2Adapter adapter = new CurveLendSDV2Adapter(MULTISTRATEGY, ASSET, harvestAddresses, crvLendSDV2Addresses, NAME, ID);

        for(uint i = 0; i < rewards.length; ++i) {
            adapter.addReward(rewards[i]);
        }

        adapter.enableGuardian(GUARDIAN);
        adapter.transferOwnership(ProtocolArbitrum.MULTI_MANAGER);

        vm.stopBroadcast();

        console.log("CRV Lend StakeDAO Adapter:", address(adapter));
    }
}