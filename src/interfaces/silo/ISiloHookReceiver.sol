// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ISiloHookReceiver {
    function configuredGauges(address _market) external view returns (address);
}