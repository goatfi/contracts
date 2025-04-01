// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

interface IClaimRewardsXChain {
    function claimRewards(address[] calldata _gauges) external;
}