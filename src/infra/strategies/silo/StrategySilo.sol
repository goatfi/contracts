// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {BaseAllToNativeStrat} from "../common/BaseAllToNativeStrat.sol";
import {ISilo, ISiloLens, ISiloRewards, ISiloCollateralToken} from "interfaces/silo/ISilo.sol";

contract StrategySilo is BaseAllToNativeStrat {
    using SafeERC20 for IERC20;

    address public silo;
    address public collateral;
    address[] public rewardsClaim;

    ISiloRewards public constant siloRewards =
        ISiloRewards(0xd592F705bDC8C1B439Bd4D665Ed99C4FaAd5A680);
    ISiloLens public constant siloLens =
        ISiloLens(0xBDb843c7a7e48Dc543424474d7Aa63b61B5D9536);

    uint256 public constant DURATION = 1 days;

    function initialize(
        address _native,
        address _collateral,
        address _silo,
        address[] calldata _rewards,
        CommonAddresses calldata _commonAddresses
    ) public initializer {
        silo = _silo;
        collateral = _collateral;
        address _want = ISiloCollateralToken(collateral).asset();

        __BaseStrategy_init(_want, _native, _rewards, _commonAddresses);
        setHarvestOnDeposit(true);

        rewardsClaim.push(collateral);
    }

    // it calculates how much 'want' the strategy has working in the farm.
    function balanceOfPool() public view override returns (uint256) {
        uint256 totalDeposits = siloLens.totalDepositsWithInterest(silo, want);
        return
            siloLens.balanceOfUnderlying(
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
    }

    function _removeAllowances() internal override {
        IERC20(want).approve(silo, 0);
    }
}
