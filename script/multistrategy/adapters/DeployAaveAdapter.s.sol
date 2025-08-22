// SPDX-License-Identifier: MIT
pragma solidity^0.8.20;

import { DeployAdapterBase } from "../../DeployAdapterBase.sol";
import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import { IPool } from "interfaces/aave/IPool.sol";
import { IAToken } from "interfaces/aave/IAToken.sol";
import { AaveAdapter } from "src/infra/multistrategy/adapters/AaveAdapter.sol";
import { Addressbook } from "@addressbook/AddressBook.sol";

/// @title Deploys an AAVE Adapter
contract DeployAaveAdapter is DeployAdapterBase {
    Addressbook addressbook = new Addressbook();

    function run(
        address multistrategy, 
        string memory name
    ) public {

        address asset = IERC4626(multistrategy).asset();
        address manager = addressbook.getManager(block.chainid);
        address guardian = addressbook.getGuardian(block.chainid);
        address aave_pool = getAavePool(block.chainid);
        address a_token = IPool(aave_pool).getReserveData(asset).aTokenAddress;

        require(IAToken(a_token).UNDERLYING_ASSET_ADDRESS() == asset, "aToken underlying asset mismatch");

        vm.startBroadcast();

        AaveAdapter adapter = new AaveAdapter(multistrategy, asset, aave_pool, a_token, name, "AAVE");

        adapter.enableGuardian(guardian);
        adapter.transferOwnership(manager);

        vm.stopBroadcast();

        _postDeploymentCheck(multistrategy, address(adapter));
    }

    function getAavePool(uint256 chainId) private pure returns (address) {
        if (chainId == 42161) return 0x794a61358D6845594F94dc1DB02A252b5b4814aD; // Arbitrum
        revert("Unsupported network");
    }

}