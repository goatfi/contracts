// SPDX-License-Identifier: MIT

pragma solidity^0.8.20;

import { Script} from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { AdapterDebtRatioThresholdRegistry } from "src/infra/utilities/AdapterDebtRatioThresholdRegistry.sol";

contract DeployAdapterDebtRatioThresholdRegistry is Script {
    address initialOwner = 0xbd297B4f9991FD23f54e14111EE6190C4Fb9F7e1;
    function run() external {
        vm.startBroadcast();
        address registry = address(new AdapterDebtRatioThresholdRegistry(initialOwner));
        vm.stopBroadcast();

        console.log(registry);
    }
}