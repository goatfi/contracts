// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ISiloV2IncetivesModule {
    function getNotificationReceivers() external view returns (address[] memory);
}