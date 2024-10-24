// SPDX-License-Identifier: MIT
pragma solidity^0.8.20;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { TimelockController } from "@openzeppelin/contracts/governance/TimelockController.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { Multicall } from "src/utils/Multicall.sol";
import { GoatAppMulticall } from "src/utils/GoatAppMulticall.sol";
import { GoatSwapper } from "src/infra/GoatSwapper.sol";
import { AssetsArbitrum } from "@addressbook/AssetsArbitrum.sol";
import { ProtocolArbitrum } from "@addressbook/ProtocolArbitrum.sol";
import { GoatBoost } from "src/infra/boost/GoatBoost.sol";
import { BoostFactory } from "src/infra/boost/BoostFactory.sol";
import { GoatVaultFactory } from "src/infra/vault/GoatVaultFactory.sol";

contract DeployProtocol is Script {

    function run() public {
        /////////////////////////////////////////////////////////
        //                      CONFIG                         //
        /////////////////////////////////////////////////////////
        address treasury = ProtocolArbitrum.TREASURY;

        /////////////////////////////////////////////////////////
        //                      TIMELOCK                       //
        /////////////////////////////////////////////////////////
        uint mindelay = vm.envUint("TIMELOCK_MIN_DELAY");
        address[] memory proposers = new address[](1);
        address[] memory executors = new address[](1);
        proposers[0] = treasury;
        executors[0] = treasury;

        /////////////////////////////////////////////////////////
        //                      SWAPPER                        //
        /////////////////////////////////////////////////////////
        address keeper = 0xbd297B4f9991FD23f54e14111EE6190C4Fb9F7e1;

        vm.startBroadcast();

        address timelock = address(new TimelockController(mindelay, proposers, executors, address(0)));
        address swapper = address(new GoatSwapper(AssetsArbitrum.WETH, keeper));
        address multicall = address(new Multicall());
        address appMulticall = address(new GoatAppMulticall(address(0), address(0)));
        address vaultFactory = address(new GoatVaultFactory(address(0)));
        address boostImpl = address(new GoatBoost());
        address boostFactory = address(new BoostFactory(vaultFactory, boostImpl));

        vm.stopBroadcast();

        console.log("Timelock", timelock);
        console.log("Swapper", swapper);
        console.log("Multicall", multicall);
        console.log("App Multicall", appMulticall);
        console.log("Goat Vault Factory:",vaultFactory);
        console.log("BoostFactory at:", boostFactory);
    }
}