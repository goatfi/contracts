// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

interface IProtocolController {
    struct Gauge {
        address vault;
        address asset;
        address rewardReceiver;
        bytes4 protocolId;
        bool isShutdown;
    }

    function gauge(address _gauge) external view returns (Gauge memory);
}