// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import { SafeERC20, IERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { BaseAllToNativeStrat } from "../common/BaseAllToNativeStrat.sol";
import { IConvexBoosterL2, ICrvMinter, IConvexRewardPool, IRewardsGauge } from "interfaces/curvelend/ICurveLend.sol";

contract StrategyCurveLend is BaseAllToNativeStrat {
    using SafeERC20 for IERC20;

    // this `pid` means we using Curve gauge and not Convex rewardPool
    uint public constant NO_PID = 42069;

    IConvexBoosterL2 public constant booster =
        IConvexBoosterL2(0xF403C135812408BFbE8713b5A23a04b3D48AAE31);
    ICrvMinter public constant minter =
        ICrvMinter(0xabC000d88f23Bb45525E447528DBF656A9D55bf5);

    address public gauge; // curve gauge
    address public rewardPool; // convex base reward pool
    uint public pid; // convex booster poolId

    bool public isCrvMintable; // if CRV can be minted via Minter (gauge is added to Controller)
    bool public isCurveRewardsClaimable; // if extra rewards in curve gauge should be claimed

    function initialize(
        address _native,
        address _want,
        address _gauge,
        uint _pid,
        address _depositToken,
        address[] calldata _rewards,
        CommonAddresses calldata _commonAddresses
    ) public initializer {
        if (_pid != NO_PID) {
            pid = _pid;
            (_want, gauge, rewardPool, , ) = booster.poolInfo(_pid);
        } else {
            gauge = _gauge;
            isCrvMintable = true;
        }

        if (_rewards.length > 1) {
            isCurveRewardsClaimable = true;
        }

        __BaseStrategy_init(_want, _native, _rewards, _commonAddresses);
        setDepositToken(_depositToken);
        setHarvestOnDeposit(true);
    }

    function balanceOfPool() public view override returns (uint) {
        return
            rewardPool != address(0)
                ? IConvexRewardPool(rewardPool).balanceOf(address(this))
                : IRewardsGauge(gauge).balanceOf(address(this));
    }

    function _deposit(uint amount) internal override {
        if (rewardPool != address(0)) {
            booster.deposit(pid, amount);
        } else {
            IRewardsGauge(gauge).deposit(amount);
        }
    }

    function _withdraw(uint amount) internal override {
        if (amount > 0) {
            if (rewardPool != address(0)) {
                IConvexRewardPool(rewardPool).withdraw(amount, false);
            } else {
                IRewardsGauge(gauge).withdraw(amount);
            }
        }
    }

    function _emergencyWithdraw() internal override {
        uint amount = balanceOfPool();
        if (amount > 0) {
            if (rewardPool != address(0)) {
                IConvexRewardPool(rewardPool).emergencyWithdraw(amount);
            } else {
                IRewardsGauge(gauge).withdraw(amount);
            }
        }
    }

    function _claim() internal override {
        if (rewardPool != address(0)) {
            IConvexRewardPool(rewardPool).getReward(address(this));
        } else {
            if (isCrvMintable) minter.mint(gauge);
            if (isCurveRewardsClaimable)
                IRewardsGauge(gauge).claim_rewards(address(this));
        }
    }

    function _verifyRewardToken(address token) internal view override {
        require(token != gauge, "!gauge");
        require(token != rewardPool, "!rewardPool");
    }

    function _giveAllowances() internal override {
        uint amount = type(uint).max;
        IERC20(want).forceApprove(gauge, amount);
        if (pid != NO_PID) IERC20(want).forceApprove(address(booster), amount);
        
        IERC20(native).forceApprove(unirouter, amount);
    }

    function _removeAllowances() internal override {
        IERC20(want).forceApprove(gauge, 0);
        IERC20(want).forceApprove(address(booster), 0);
        IERC20(native).forceApprove(unirouter, 0);
    }
}
