// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import { BaseAllToNativeStrat } from "../common/BaseAllToNativeStrat.sol";
import { IVStaker, LpStake, SD59x18 } from "interfaces/virtuswap/IVStaker.sol";

contract StrategyVirtuswap is BaseAllToNativeStrat {
    IVStaker public constant vstaker = IVStaker(0x68748818983CD5B4cD569E92634b8505CFc41FE8);

    function initialize(
        address _native,
        address _want,
        address _depositToken,
        address[] calldata _rewards,
        CommonAddresses calldata _commonAddresses
    ) public initializer {
        __BaseStrategy_init(_want, _native, _rewards, _commonAddresses);
        setDepositToken(_depositToken);
        setHarvestOnDeposit(true);
    }

    function unwrap(SD59x18 x) internal pure returns (int256 result) {
        result = SD59x18.unwrap(x);
    }

    function balanceOfPool() public view override returns (uint) {
        uint lpIndex = vstaker.lpStakeIndex(address(this), want);
        if (lpIndex == 0) return 0;

        LpStake[] memory lpStakes = vstaker.viewLpStakes();
        return uint256(unwrap(lpStakes[lpIndex].amount));
    }

    function _deposit(uint amount) internal override {
        vstaker.stakeLp(want, amount);
    }

    function _withdraw(uint amount) internal override {
        vstaker.unstakeLp(want, amount);
    }

    function _emergencyWithdraw() internal override {
        uint amount = balanceOfPool();
        if (amount > 0) {
            vstaker.unstakeLp(want, amount);
        }
    }

    function _claim() internal override {
        vstaker.claimRewards(want);
    }

    function _verifyRewardToken(address token) internal pure override {
        require(token != address(vstaker), "!stakePool");
    }

    function _giveAllowances() internal override {
        _approve(want, address(vstaker), type(uint).max);
        _approve(native, address(unirouter), type(uint).max);
    }

    function _removeAllowances() internal override {
        _approve(want, address(vstaker), 0);
        _approve(native, address(unirouter), 0);
    }
}