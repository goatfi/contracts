// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IGoatBoost {
    function initialize(
        address _stakedToken,
        address _rewardToken,
        uint256 _duration,
        address _manager,
        address _treasury
    ) external;
    function setTreasuryFee(uint256 _fee) external;
    function transferOwnership(address owner) external;
}