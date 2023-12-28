// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract GoatFarm is OwnableUpgradeable {
    using SafeERC20 for IERC20;

    IERC20 public stakedToken;
    IERC20 public rewardToken;
    uint256 public duration;

    uint256 public periodFinish;
    uint256 public rewardRate;
    uint256 public lastUpdateTime;
    uint256 public rewardPerTokenStored;
    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards;
    uint256 public rewardBalance;

    address public manager;
    uint256 private _totalSupply;

    mapping(address => bool) public notifiers;
    mapping(address => uint256) private _balances;

    event RewardAdded(uint256 reward);
    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);

    function initialize(address _stakedToken, address _rewardToken, uint256 _duration, address _manager) public initializer {
        __Ownable_init(_manager);
        stakedToken = IERC20(_stakedToken);
        rewardToken = IERC20(_rewardToken);
        duration = _duration;
        manager = _manager;
    }

    modifier onlyManager() {
        require(msg.sender == manager || msg.sender == owner(), "!manager");
        _;
    }

    modifier onlyNotifier() {
        require(msg.sender == manager || msg.sender == owner() || notifiers[msg.sender], "!notifier");
        _;
    }

    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = lastTimeRewardApplicable();
        if (account != address(0)) {
            rewards[account] = earned(account);
            userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }
        _;
    }

    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }

    function lastTimeRewardApplicable() public view returns (uint256) {
        return Math.min(block.timestamp, periodFinish);
    }

    function rewardPerToken() public view returns (uint256) {
        if (totalSupply() == 0) {
            return rewardPerTokenStored;
        }
        return rewardPerTokenStored + ((lastTimeRewardApplicable() - lastUpdateTime) * rewardRate * 1e18 / totalSupply());
    }

    function earned(address account) public view returns (uint256) {
        return balanceOf(account) * (rewardPerToken() - userRewardPerTokenPaid[account]) / 1e18 + rewards[account];
    }

    function stake(uint256 amount) external updateReward(msg.sender) {
        require(amount > 0, "Cannot stake 0");
        _totalSupply += amount;
        _balances[msg.sender] += amount;
        stakedToken.safeTransferFrom(msg.sender, address(this), amount);
        emit Staked(msg.sender, amount);
    }

    function withdraw(uint256 amount) public updateReward(msg.sender) {
        require(amount > 0, "Cannot withdraw 0");
        _totalSupply -= amount;
        _balances[msg.sender] -= amount;
        stakedToken.safeTransfer(msg.sender, amount);
        emit Withdrawn(msg.sender, amount);
    }

    function exit() external {
        withdraw(balanceOf(msg.sender));
        getReward();
    }

    function getReward() public updateReward(msg.sender) {
        uint256 reward = earned(msg.sender);
        if (reward > 0) {
            rewards[msg.sender] = 0;
            rewardBalance -= reward;
            rewardToken.safeTransfer(msg.sender, reward);
            emit RewardPaid(msg.sender, reward);
        }
    }

    function setRewardDuration(uint256 _duration) external onlyManager {
        require(block.timestamp >= periodFinish);
        duration = _duration;
    }

    function setNotifier(address _notifier, bool _enable) external onlyManager {
        notifiers[_notifier] = _enable;
    }

    function _notify(uint256 reward) internal updateReward(address(0)) {
        require(reward != 0, "no rewards");
        if (block.timestamp >= periodFinish) {
            rewardRate = reward / duration;
        } else {
            uint256 remaining = periodFinish - block.timestamp;
            uint256 leftover = remaining * rewardRate;
            rewardRate = (reward + leftover) / duration;
        }
        lastUpdateTime = block.timestamp;
        periodFinish = block.timestamp + duration;
        rewardBalance += reward;
        emit RewardAdded(reward);
    }

    function notifyAmount(uint256 _amount) external onlyNotifier {
        rewardToken.safeTransferFrom(msg.sender, address(this), _amount);
        _notify(_amount);
    }

    function notifyAlreadySent() external onlyNotifier {
        uint256 balance = rewardToken.balanceOf(address(this));
        uint256 userRewards = rewardBalance;
        if (rewardToken == stakedToken) {
            userRewards = userRewards + totalSupply();
        }
        uint256 newRewards = balance - userRewards;
        _notify(newRewards);
    }

    function inCaseTokensGetStuck(address _token) external onlyManager {
        uint256 amount = IERC20(_token).balanceOf(address(this));
        inCaseTokensGetStuck(_token, msg.sender, amount);
    }

    function inCaseTokensGetStuck(address _token, address _to, uint256 _amount) public onlyManager {
        if (totalSupply() != 0) {
            require(_token != address(stakedToken), "!staked");
        }
        IERC20(_token).safeTransfer(_to, _amount);
    }
}
