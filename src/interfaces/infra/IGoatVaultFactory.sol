// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { GoatVault } from "src/infra/vault/GoatVault.sol";

interface IGoatVaultFactory {
    function cloneVault() external returns (GoatVault);
    function cloneContract(address implementation) external returns (address);
}