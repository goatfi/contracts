// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ISiloV2Vault {
    function INCENTIVES_MODULE() external view returns (address);
    function withdrawQueue(uint256 _index) external view returns (address);
    function withdrawQueueLength() external view returns (uint256);
}