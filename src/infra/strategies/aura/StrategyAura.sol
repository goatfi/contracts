// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import { SafeERC20, IERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { BaseAllToNativeStrat } from "../common/BaseAllToNativeStrat.sol";
import { IAuraBooster, IAuraRewardPool } from "interfaces/aura/IAura.sol";

contract StrategyAura is BaseAllToNativeStrat {
    using SafeERC20 for IERC20;

    IAuraBooster public constant booster = IAuraBooster(0x98Ef32edd24e2c92525E59afc4475C1242a30184);

    address public rewardPool;
    uint256 public pid;

    error DepositError();
    error WithdrawError();
    error ClaimError();
    error PoolShutdown();

    function initialize(
        uint _pid,
        address _native,
        address _depositToken,
        address[] calldata _rewards,
        CommonAddresses calldata _commonAddresses
    ) public initializer {
        pid = _pid;
        IAuraBooster.PoolInfo memory pInfo = booster.poolInfo(pid);
        if(pInfo.shutdown) revert PoolShutdown();

        rewardPool = pInfo.crvRewards;

        __BaseStrategy_init(pInfo.lptoken, _native, _rewards, _commonAddresses);
        setDepositToken(_depositToken);
        setHarvestOnDeposit(true);
    }

    function balanceOfPool() public view override returns (uint256) {
        return IAuraRewardPool(rewardPool).balanceOf(address(this));
    }

    function _deposit(uint _amount) internal override {
        bool success = booster.deposit(pid, _amount, true);
        if(!success) revert DepositError();
    }

    function _withdraw(uint _amount) internal override {
        bool success = IAuraRewardPool(rewardPool).withdrawAndUnwrap(_amount, false);
        if(!success) revert WithdrawError();
    }

    function _emergencyWithdraw() internal override {
        IAuraRewardPool(rewardPool).withdrawAllAndUnwrap(false);
    }

    function _claim() internal override {
        bool success = IAuraRewardPool(rewardPool).getReward();
        if(!success) revert ClaimError();
    }

    function rewardsAvailable() public view override returns (uint256) {
        return IAuraRewardPool(rewardPool).earned(address(this));
    }

    function _verifyRewardToken(address token) internal view override {
        require(token != address(booster) && token != rewardPool, "!rewardToken");
    }

    function _giveAllowances() internal override {
        IERC20(want).forceApprove(address(booster), type(uint).max);
        IERC20(native).forceApprove(unirouter, type(uint).max);
    }

    function _removeAllowances() internal override {
        IERC20(want).forceApprove(address(booster), 0);
        IERC20(native).forceApprove(unirouter, 0);
    }
}
