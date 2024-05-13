// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IGoatBoost {
    // Variables
    function stakedToken() external view returns (IERC20);
    function rewardToken() external view returns (IERC20);
    function duration() external view returns (uint256);
    function owner() external view returns (address);
    function manager() external view returns (address);
    function treasury() external view returns (address);
    function treasuryFee() external view returns (uint256);
    function isPreStake() external view returns (bool);
    function notifiers(address account) external view returns(bool);

    // Functions
    function initialize(
        address _stakedToken,
        address _rewardToken,
        uint256 _duration,
        address _manager,
        address _treasury
    ) external;
    function transferOwnership(address owner) external;
    function setTreasury(address treasury) external;
    function setTreasuryFee(uint256 fee) external;
    function stake(uint256 amount) external;
    function withdraw(uint256 amount) external;
    function exit() external;
    function getReward() external;
    function totalSupply() external returns (uint256);
    function earned(address account) external returns (uint256);
    function balanceOf(address account) external returns (uint256);
    function setRewardDuration(uint256 duration) external;
    function openPreStake() external;
    function closePreStake() external;
    function notifyAmount(uint256 amount) external;
    function setNotifier(address account, bool enable) external;
    function inCaseTokensGetStuck(address _token) external;
    function inCaseTokensGetStuck(address _token, address _to, uint _amount) external;
}