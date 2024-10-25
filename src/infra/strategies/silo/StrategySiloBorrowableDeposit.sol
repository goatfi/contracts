// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import { BaseAllToNativeStrat, IERC20 } from "../common/BaseAllToNativeStrat.sol";
import { ISilo, ISiloLens, ISiloRewards, ISiloCollateralToken } from "interfaces/silo/ISilo.sol";

contract StrategySiloBorrowableDeposit is BaseAllToNativeStrat {
    ISiloLens siloLens;
    ISiloRewards siloRewards;
    address public silo;
    address public collateral;
    address[] public rewardsClaim;

    function initialize(
        address _native,
        address _collateral,
        address _silo,
        address _siloLens,
        address _siloRewards,
        address[] calldata _rewards,
        CommonAddresses calldata _commonAddresses
    ) public initializer {
        collateral = _collateral;
        silo = _silo;
        siloLens = ISiloLens(_siloLens);
        siloRewards = ISiloRewards(_siloRewards);
        address _want = ISiloCollateralToken(collateral).asset();

        __BaseStrategy_init(_want, _native, _rewards, _commonAddresses);
        setHarvestOnDeposit(true);

        rewardsClaim.push(collateral);
    }

    // it calculates how much 'want' the strategy has working in the farm.
    function balanceOfPool() public view override returns (uint256) {
        uint256 totalDeposits = siloLens.totalDepositsWithInterest(silo, want);
        return siloLens.balanceOfUnderlying(
                totalDeposits, 
                collateral, 
                address(this)
            );
    }

    function _deposit(uint amount) internal override {
        ISilo(silo).deposit(want, amount, false);
    }

    function _withdraw(uint amount) internal override {
        ISilo(silo).withdraw(want, amount, false);
    }

    function _emergencyWithdraw() internal override {
        uint amount = balanceOfPool();
        if (amount > 0) {
            ISilo(silo).withdraw(want, amount, false);
        }
    }

    function _claim() internal override {
        siloRewards.claimRewardsToSelf(rewardsClaim, type(uint).max);
    }

    function _verifyRewardToken(address token) internal view override {
        require(token != silo, "!rewardToken");
    }

    function _giveAllowances() internal override {
        IERC20(want).approve(silo, type(uint).max);
        IERC20(native).approve(unirouter, type(uint).max);
    }

    function _removeAllowances() internal override {
        IERC20(want).approve(silo, 0);
        IERC20(native).approve(unirouter, 0);
    }
}
