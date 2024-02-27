// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import { GoatVault } from "./GoatVault.sol";
import { Clones } from "@openzeppelin/contracts/proxy/Clones.sol";
import { IStrategy } from "interfaces/infra/IStrategy.sol";

contract GoatVaultFactory {
    using Clones for address;

    /// @notice Contract template for deploying proxied Goat vaults
    GoatVault public instance;

    /// @notice A new proxy has been created
    /// @param proxy Address of the proxy created
    event ProxyCreated(address proxy);

    /// @notice Initializes the factory contract
    /// @param _instance Address of the GoatVault instance
    constructor(address _instance) {
        if (_instance == address(0)) {
            instance = new GoatVault();
        } else {
            instance = GoatVault(_instance);
        }
        instance.initialize(IStrategy(address(0)), "Goat Vault Implementation", "GVI", 0);
        instance.renounceOwnership();
    }

    /// @notice Creates a new Goat Vault as a proxy of the template instance
    function cloneVault() external returns (GoatVault) {
        return GoatVault(cloneContract(address(instance)));
    }

    /// @notice Deploys and returns the address of a clone that mimics the behaviour of `implementation`
    /// @param _implementation Implementation to clone
    function cloneContract(address _implementation) public returns (address) {
        address proxy = _implementation.clone();
        emit ProxyCreated(proxy);
        return proxy;
    }
}