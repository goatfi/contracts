// SPDX-License-Identifier: MIT
pragma solidity^0.8.20;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { CurveLendAdapter } from "src/infra/multistrategy/adapters/CurveLendAdapter.sol";
import { AssetsArbitrum, ProtocolArbitrum, VaultsArbitrum } from "@addressbook/AddressBook.sol";
import { StrategyAdapterHarvestable } from "src/abstracts/StrategyAdapterHarvestable.sol";

contract DeployCurveLendAdapter is Script {
    address[] rewards = [AssetsArbitrum.CRV];

    address constant LEND_VAULT = 0x0E6Ad128D7E217439bEEa90695FE7ec859c7F98C;
    address constant GAUGE = address(0);
    address constant GAUGE_FACTORY = 0xabC000d88f23Bb45525E447528DBF656A9D55bf5;

    /////////////////////////////////////////////////////////
    //                   ADAPTER CONFIG                    //
    /////////////////////////////////////////////////////////
    address constant MULTISTRATEGY = VaultsArbitrum.ycCRVUSD;
    address constant ASSET = AssetsArbitrum.CRVUSD;
    address constant GUARDIAN = 0xbd297B4f9991FD23f54e14111EE6190C4Fb9F7e1;
    string constant NAME = "Curve Lend tBTC";                            //FIXME:
    string constant ID = "CRV-LEND";

    StrategyAdapterHarvestable.HarvestAddresses harvestAddresses = StrategyAdapterHarvestable.HarvestAddresses({
        swapper: ProtocolArbitrum.GOAT_SWAPPER,
        wrappedGas: AssetsArbitrum.WETH
    });

    CurveLendAdapter.CurveLendAddresses crvLendSDAddresses = CurveLendAdapter.CurveLendAddresses({
        vault: LEND_VAULT,
        gauge: GAUGE,
        gaugeFactory: GAUGE_FACTORY
    });

    function run() public {

        /////////////////////////////////////////////////////////
        //                 ADAPTER DEPLOYMENT                  //
        /////////////////////////////////////////////////////////

        vm.startBroadcast();

        CurveLendAdapter adapter = new CurveLendAdapter(MULTISTRATEGY, ASSET, harvestAddresses, crvLendSDAddresses, NAME, ID);

        if(GAUGE != address(0)) {
            for(uint i = 0; i < rewards.length; ++i) {
                adapter.addReward(rewards[i]);
            }
        }

        adapter.enableGuardian(GUARDIAN);
        adapter.transferOwnership(ProtocolArbitrum.MULTI_MANAGER);

        vm.stopBroadcast();

        console.log("CRV Lend Adapter:", address(adapter));
    }
}