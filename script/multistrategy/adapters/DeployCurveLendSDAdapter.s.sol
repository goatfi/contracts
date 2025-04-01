// SPDX-License-Identifier: MIT
pragma solidity^0.8.20;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { CurveLendSDAdapter } from "src/infra/multistrategy/adapters/CurveLendSDAdapter.sol";
import { AssetsArbitrum, ProtocolArbitrum } from "@addressbook/AddressBook.sol";
import { StrategyAdapterHarvestable } from "src/abstracts/StrategyAdapterHarvestable.sol";

contract DeployCurveLendSDAdapter is Script {
    address[] rewards = [AssetsArbitrum.CRV];

    address constant CRV_LEND_VAULT = 0xd3cA9BEc3e681b0f578FD87f20eBCf2B7e0bb739;
    address constant SD_VAULT = 0x37E939aA581d01767249d4AaB9BE2b328bE2FD3C;
    address constant SD_REWARDS = 0xAbf4368d120190B4F111C30C92cc9f8f6a6BE233;

    /////////////////////////////////////////////////////////
    //                   ADAPTER CONFIG                    //
    /////////////////////////////////////////////////////////
    address constant MULTISTRATEGY = 0xA7781F1D982Eb9000BC1733E29Ff5ba2824cDBE5;
    address constant ASSET = AssetsArbitrum.CRVUSD;
    address constant GUARDIAN = 0xbd297B4f9991FD23f54e14111EE6190C4Fb9F7e1;
    string constant NAME = "Stake DAO Curve Lend WETH Lev";                            //FIXME:
    string constant ID = "CRVLEND-SD";

    StrategyAdapterHarvestable.HarvestAddresses harvestAddresses = StrategyAdapterHarvestable.HarvestAddresses({
        swapper: ProtocolArbitrum.GOAT_SWAPPER,
        wrappedGas: AssetsArbitrum.WETH
    });

    CurveLendSDAdapter.CurveLendSDAddresses crvLendSDAddresses = CurveLendSDAdapter.CurveLendSDAddresses({
        lendVault: CRV_LEND_VAULT,
        sdVault: SD_VAULT,
        sdRewards: SD_REWARDS
    });

    function run() public {

        /////////////////////////////////////////////////////////
        //                 ADAPTER DEPLOYMENT                  //
        /////////////////////////////////////////////////////////

        vm.startBroadcast();

        CurveLendSDAdapter adapter = new CurveLendSDAdapter(MULTISTRATEGY, ASSET, harvestAddresses, crvLendSDAddresses, NAME, ID);

        for(uint i = 0; i < rewards.length; ++i) {
            adapter.addReward(rewards[i]);
        }

        adapter.enableGuardian(GUARDIAN);
        adapter.transferOwnership(ProtocolArbitrum.MULTI_MANAGER);

        vm.stopBroadcast();

        console.log("CRV Lend StakeDAO Adapter:", address(adapter));
    }
}