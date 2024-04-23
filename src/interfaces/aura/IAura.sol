// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

interface IAuraBooster {
    struct PoolInfo {
        address lptoken;
        address token;
        address gauge;
        address crvRewards;
        address stash;
        bool shutdown;
    }

    function poolInfo(uint index) external view returns (PoolInfo memory info);

    function deposit(
        uint256 _pid,
        uint256 _amount,
        bool _stake
    ) external returns (bool);

    function withdraw(uint256 _pid, uint256 _amount) external returns (bool);

    function withdrawAll(uint256 _pid) external returns (bool);
}

interface IBaseRewardPool {
    function getReward() external returns (bool);

    function withdrawAndUnwrap(
        uint256 amount,
        bool claim
    ) external returns (bool);

    function withdrawAllAndUnwrap(bool claim) external;
}
