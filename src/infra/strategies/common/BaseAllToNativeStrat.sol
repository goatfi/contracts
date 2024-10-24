// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import { SafeERC20, IERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IGoatSwapper } from "interfaces/infra/IGoatSwapper.sol";
import { StratFeeManagerInitializable } from "./StratFeeManagerInitializable.sol";
import { IFeeConfig } from "interfaces/common/IFeeConfig.sol";

abstract contract BaseAllToNativeStrat is StratFeeManagerInitializable {
    using SafeERC20 for IERC20;

    address[] public rewards;
    mapping(address => uint) public minAmounts; // tokens minimum amount to be swapped

    address public want;
    address public native;
    address public depositToken;
    uint256 public lastHarvest;
    uint256 public totalLocked;
    uint256 public lockDuration;
    bool public harvestOnDeposit;

    event StratHarvest(address indexed harvester, uint256 wantHarvested, uint256 tvl);
    event Deposit(uint256 tvl);
    event Withdraw(uint256 tvl);
    event ChargedFees(uint256 callFees, uint256 protocolFees, uint256 strategistFees);

    function __BaseStrategy_init(address _want, address _native, address[] calldata _rewards, CommonAddresses calldata _commonAddresses) internal onlyInitializing {
        __StratFeeManager_init(_commonAddresses);
        want = _want;
        native = _native;

        for (uint i; i < _rewards.length; i++) {
            addReward(_rewards[i]);
        }

        lockDuration = 1 days;
        setWithdrawalFee(0);
        _giveAllowances();
    }

    // it calculates how much 'want' the strategy has working in the farm.
    function balanceOfPool() public view virtual returns (uint);
    function _deposit(uint amount) internal virtual;
    function _withdraw(uint amount) internal virtual;
    function _emergencyWithdraw() internal virtual;
    function _claim() internal virtual;
    function _verifyRewardToken(address token) internal view virtual;
    function _giveAllowances() internal virtual;
    function _removeAllowances() internal virtual;

    // puts the funds to work
    function deposit() public whenNotPaused {
        uint256 wantBal = balanceOfWant();
        if (wantBal > 0) {
            _deposit(wantBal);
            emit Deposit(balanceOf());
        }
    }

    function withdraw(uint256 _amount) external {
        require(msg.sender == vault, "!vault");

        uint256 wantBal = balanceOfWant();

        if (wantBal < _amount) {
            _withdraw(_amount - wantBal);
            wantBal = balanceOfWant();
        }

        if (wantBal > _amount) {
            wantBal = _amount;
        }

        if (tx.origin != owner() && !paused()) {
            uint256 withdrawalFeeAmount = wantBal * withdrawalFee / WITHDRAWAL_MAX;
            wantBal = wantBal - withdrawalFeeAmount;
        }

        IERC20(want).safeTransfer(vault, wantBal);

        emit Withdraw(balanceOf());
    }

    function beforeDeposit() external override {
        if (harvestOnDeposit) {
            require(msg.sender == vault, "!vault");
            _harvest(tx.origin, true);
        }
    }

    function harvest() external virtual {
        _harvest(tx.origin, false);
    }

    function harvest(address callFeeRecipient) external virtual {
        _harvest(callFeeRecipient, false);
    }

    // compounds earnings and charges performance fee
    function _harvest(address callFeeRecipient, bool onDeposit) internal whenNotPaused {
        _claim();
        _swapRewardsToNative();
        uint256 nativeBal = IERC20(native).balanceOf(address(this));
        if (nativeBal > minAmounts[native]) {
            _chargeFees(callFeeRecipient);
            _swapNativeToWant();
            uint256 wantHarvested = balanceOfWant();
            totalLocked = wantHarvested + lockedProfit();
            lastHarvest = block.timestamp;

            if (!onDeposit) {
                deposit();
            }

            emit StratHarvest(msg.sender, wantHarvested, balanceOf());
        }
    }

    function _swapRewardsToNative() internal virtual {
        for (uint i; i < rewards.length; ++i) {
            address token = rewards[i];
            uint256 amount = IERC20(token).balanceOf(address(this));
            if (amount > minAmounts[token]) {
                IGoatSwapper(unirouter).swap(token, native, amount);
            }
        }
    }

    // performance fees
    function _chargeFees(address callFeeRecipient) internal {
        IFeeConfig.FeeCategory memory fees = getFees();
        uint256 nativeBal = IERC20(native).balanceOf(address(this)) * fees.total / DIVISOR;

        uint256 callFeeAmount = nativeBal * fees.call / DIVISOR;
        IERC20(native).safeTransfer(callFeeRecipient, callFeeAmount);

        uint256 protocolFeeAmount = nativeBal * fees.protocol / DIVISOR;
        IERC20(native).safeTransfer(protocolFeeRecipient, protocolFeeAmount);

        uint256 strategistFeeAmount = nativeBal * fees.strategist / DIVISOR;
        IERC20(native).safeTransfer(strategist, strategistFeeAmount);

        emit ChargedFees(callFeeAmount, protocolFeeAmount, strategistFeeAmount);
    }

    function _swapNativeToWant() internal virtual {
        if (depositToken == address(0)) {
            if(native != want) {
                _swap(native, want);
            }
        } else {
            if (depositToken != native) {
                _swap(native, depositToken);
            }
            _swap(depositToken, want);
        }
    }

    function _swap(address tokenFrom, address tokenTo) internal {
        uint bal = IERC20(tokenFrom).balanceOf(address(this));
        IGoatSwapper(unirouter).swap(tokenFrom, tokenTo, bal);
    }

    function rewardsLength() external view returns (uint) {
        return rewards.length;
    }

    function addReward(address _token) public onlyManager {
        require(_token != want, "!want");
        require(_token != native, "!native");
        _verifyRewardToken(_token);

        rewards.push(_token);
        _approve(_token, unirouter, 0);
        _approve(_token, unirouter, type(uint).max);
    }

    function removeReward(uint i) external onlyManager {
        rewards[i] = rewards[rewards.length - 1];
        rewards.pop();
    }

    function resetRewards() external onlyManager {
        for (uint i; i < rewards.length; ++i) {
            _approve(rewards[i], unirouter, 0);
        }
        delete rewards;
    }

    function setRewardMinAmount(address token, uint minAmount) external onlyManager {
        minAmounts[token] = minAmount;
    }

    function updateUnirouter(address _unirouter) external onlyOwner {
        for (uint i; i < rewards.length; ++i) {
            address token = rewards[i];
            _approve(token, unirouter, 0);
            _approve(token, _unirouter, 0);
            _approve(token, _unirouter, type(uint256).max);
        }
        _approve(native, unirouter, 0);
        _approve(native, _unirouter, 0);
        _approve(native, _unirouter, type(uint256).max);
        unirouter = _unirouter;
        emit SetUnirouter(_unirouter);
    }

    function setDepositToken(address token) public onlyManager {
        if (token == address(0)) {
            depositToken = address(0);
            return;
        }
        require(token != want, "!want");
        _verifyRewardToken(token);

        depositToken = token;
        _approve(token, unirouter, 0);
        _approve(token, unirouter, type(uint).max);
    }

    function lockedProfit() public view returns (uint256) {
        if (lockDuration == 0) return 0;
        uint256 elapsed = block.timestamp - lastHarvest;
        uint256 remaining = elapsed < lockDuration ? lockDuration - elapsed : 0;
        return totalLocked * remaining / lockDuration;
    }

    // calculate the total underlaying 'want' held by the strat.
    function balanceOf() public view returns (uint256) {
        return balanceOfWant() + balanceOfPool() - lockedProfit();
    }

    // it calculates how much 'want' this contract holds.
    function balanceOfWant() public view returns (uint256) {
        return IERC20(want).balanceOf(address(this));
    }

    function setHarvestOnDeposit(bool _harvestOnDeposit) public onlyManager {
        harvestOnDeposit = _harvestOnDeposit;
        if (harvestOnDeposit) {
            lockDuration = 0;
        } else {
            lockDuration = 1 days;
        }
    }

    function setLockDuration(uint _duration) external onlyManager {
        lockDuration = _duration;
    }

    function rewardsAvailable() external view virtual returns (uint) {
        return 0;
    }

    function callReward() external view virtual returns (uint) {
        return 0;
    }

    // called as part of strat migration. Sends all the available funds back to the vault.
    function retireStrat() external {
        require(msg.sender == vault, "!vault");
        _emergencyWithdraw();
        IERC20(want).transfer(vault, balanceOfWant());
    }

    // pauses deposits and withdraws all funds from third party systems.
    function panic() public onlyManager {
        pause();
        _emergencyWithdraw();
    }

    function pause() public onlyManager {
        _pause();
        _removeAllowances();
    }

    function unpause() external onlyManager {
        _unpause();
        _giveAllowances();
        deposit();
    }

    function _approve(address _token, address _spender, uint amount) internal {
        IERC20(_token).approve(_spender, amount);
    }
}