// SPDX-License-Identifier: MIT
pragma solidity^0.8.20;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { CurveLendSDV2Adapter } from "src/infra/multistrategy/adapters/CurveLendSDV2Adapter.sol";
import { AssetsArbitrum, ProtocolArbitrum, VaultsArbitrum } from "@addressbook/AddressBook.sol";
import { StrategyAdapterHarvestable } from "src/abstracts/StrategyAdapterHarvestable.sol";

contract DeployCurveLendSDAV2dapter is Script {
    address[] rewards = [AssetsArbitrum.CRV];

    address constant CRV_LEND_VAULT = 0xd3cA9BEc3e681b0f578FD87f20eBCf2B7e0bb739;
    address constant SD_VAULT = 0x37E939aA581d01767249d4AaB9BE2b328bE2FD3C;

    /////////////////////////////////////////////////////////
    //                   ADAPTER CONFIG                    //
    /////////////////////////////////////////////////////////
    address constant MULTISTRATEGY = VaultsArbitrum.ycCRVUSD;
    address constant ASSET = AssetsArbitrum.CRVUSD;
    address constant GUARDIAN = 0xbd297B4f9991FD23f54e14111EE6190C4Fb9F7e1;
    string constant NAME = "Stake DAO Curve Lend WETH";                            //FIXME:
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