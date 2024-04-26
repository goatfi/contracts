// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

interface IConvexBoosterL2 {
    function deposit(uint256 _pid, uint256 _amount) external returns (bool);

    function poolInfo(
        uint256 pid
    )
        external
        view
        returns (
            address lptoken, //the curve lp token
            address gauge, //the curve gauge
            address rewards, //the main reward/staking contract
            bool shutdown, //is this pool shutdown?
            address factory //a reference to the curve factory used to create this pool (needed for minting crv)
        );
}

interface ICrvMinter {
    function mint(address _gauge) external;
}

interface IConvexRewardPool {
    function balanceOf(address account) external view returns (uint256);

    function earned(address account) external view returns (uint256);

    function periodFinish() external view returns (uint256);

    function getReward() external;

    function getReward(address _account, bool _claimExtras) external;

    function getReward(address _account) external;

    function withdrawAndUnwrap(uint256 _amount, bool claim) external;

    function withdrawAllAndUnwrap(bool claim) external;

    // L2 interface
    function withdraw(uint256 _amount, bool _claim) external;

    function emergencyWithdraw(uint256 _amount) external;
}

interface IRewardsGauge {
    function balanceOf(address account) external view returns (uint256);

    function lp_token() external view returns (address);

    function claimable_reward(
        address _addr,
        address _token
    ) external view returns (uint256);

    function claim_rewards(address _addr) external;

    function deposit(uint256 _value) external;

    function withdraw(uint256 _value) external;

    function reward_contract() external view returns (address);
}
