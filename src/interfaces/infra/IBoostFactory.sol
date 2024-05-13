// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IBoostFactory {
    function deployBoost(
        address _vault, 
        address _rewardToken, 
        uint _duration,
        address _manager, 
        address _treasury
    ) external returns (address);
}