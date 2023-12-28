// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IGoatFarm {
    function owner() external view returns (address);
    function transferOwnership(address newOwner) external;
    function stakedToken() external view returns (IERC20);
    function rewardToken() external view returns (IERC20);
    function duration() external view returns (uint256);
    function periodFinish() external view returns (uint256);
    function rewardRate() external view returns (uint256);
    function lastUpdateTime() external view returns (uint256);
    function rewardPerTokenStored() external view returns (uint256);
    function userRewardPerTokenPaid(address account) external view returns (uint256);
    function rewards(address account) external view returns (uint256);
    function rewardBalance() external view returns (uint256);
    function manager() external view returns (address);
    function notifiers(address _notifier) external view returns (bool);
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function lastTimeRewardApplicable() external view returns (uint256);
    function rewardPerToken() external view returns (uint256);
    function earned(address account) external view returns (uint256);

    function stake(uint256 amount) external;
    function withdraw(uint256 amount) external;
    function exit() external;
    function getReward() external;
    function setRewardDuration(uint256 _duration) external;
    function openPreStake() external;
    function closePreStake() external;
    function setNotifier(address _notifier, bool _enable) external;
    function notifyAmount(uint256 _amount) external;
    function notifyAlreadySent() external;
    function inCaseTokensGetStuck(address _token) external;
    function inCaseTokensGetStuck(address _token, address _to, uint256 _amount) external;
}
