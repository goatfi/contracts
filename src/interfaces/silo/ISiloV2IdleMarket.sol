// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ISiloV2IdleMarket {
    function ONLY_DEPOSITOR() external view returns (address);
}