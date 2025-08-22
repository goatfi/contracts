// SPDX-License-Identifier: MIT
pragma solidity^0.8.20;

import { DeployAdapterBase } from "../../DeployAdapterBase.sol";
import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import { ERC4626Adapter } from "src/infra/multistrategy/adapters/ERC4626Adapter.sol";
import { Addressbook } from "@addressbook/AddressBook.sol";

/// @title Deploys an ERC4626 Adapter
contract DeployERC4626Adapter is DeployAdapterBase {
    Addressbook addressbook = new Addressbook();

    function run(
        address multistrategy,
        string memory name,
        string memory id,
        address erc4626_vault
    ) public {

        address asset = IERC4626(multistrategy).asset();
        address manager = addressbook.getManager(block.chainid);
        address guardian = addressbook.getGuardian(block.chainid);

        _isERC4626(erc4626_vault, asset);

        vm.startBroadcast();

        ERC4626Adapter adapter = new ERC4626Adapter(multistrategy, asset, erc4626_vault, name, id);

        adapter.enableGuardian(guardian);
        adapter.transferOwnership(manager);

        vm.stopBroadcast();

        _postDeploymentCheck(multistrategy, address(adapter));
    }
}