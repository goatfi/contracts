// SPDX-License-Identifier: MIT
pragma solidity^0.8.20;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";

contract DeployAdapterBase is Script {

    function _isContract(address _addr) internal view returns (bool) {
        uint32 size;
        assembly {
            size := extcodesize(_addr)
        }
        return (size > 0);
    }
    
    function _isERC4626(address _erc4626Vault, address _adapterAsset) internal view returns (bool) {
        try IERC4626(_erc4626Vault).asset() returns (address vaultAsset) {
            require(vaultAsset == _adapterAsset, "Vault asset mismatch");
            return true;
        } catch {
            revert("Vault does not implement IERC4626");
        }
    }

    function _verifyRewards(address[] memory _rewards, address _adapterAsset) internal view returns (bool) {
        for(uint i = 0; i < _rewards.length; i++) {
            require(_rewards[i] != _adapterAsset, "Reward cannot be the adapter asset");
            _isERC20(_rewards[i]);
        }
        return true;
    }

    function _isERC20(address _erc20Token) private view returns (bool) {
        try IERC20(_erc20Token).totalSupply() {
            return true;
        } catch {
            revert("Vault does not implement IERC4626");
        }
    }
}