// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IERC20, SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20Mock } from "interfaces/common/IERC20Mock.sol";
import { IStrategyAdapterMock } from "../shared/TestInterfaces.sol";
import { StrategyAdapter } from "src/abstracts/StrategyAdapter.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

contract StrategyAdapterMock is StrategyAdapter, IStrategyAdapterMock {
    using SafeERC20 for IERC20;

    StakingMock staking;

    constructor(
        address _multistrategy,
        address _asset
    ) 
        StrategyAdapter(_multistrategy, _asset, "Mock", "MOCK") 
    {
        staking = new StakingMock(_asset);
        IERC20(_asset).forceApprove(address(staking), type(uint256).max);
    }

    function earn(uint256 _amount) external {
        IERC20Mock(asset).mint(address(staking), _amount);
    }

    function lose(uint256 _amount) external {
        IERC20Mock(asset).burn(address(staking), _amount);
    }

    function tryWithdraw(uint256 _amount) external {
        _tryWithdraw(_amount);
    }

    function calculateGainAndLoss(uint256 _currentAssets) external view returns(uint256 gain, uint256 loss) {
        (gain, loss) = _calculateGainAndLoss(_currentAssets);
        return (gain, loss);
    }

    function calculateAmountToBeWithdrawn(uint256 _repayAmount, uint256 _strategyGain) external view returns(uint256) {
        return _calculateAmountToBeWithdrawn(_repayAmount, _strategyGain);
    }

    function calculateGainAndLossAfterSlippage(
        uint256 _gain, 
        uint256 _loss, 
        uint256 _withdrawn, 
        uint256 _toBeWithdrawn
        ) external pure returns (uint256, uint256) {
        return _calculateGainAndLossAfterSlippage(_gain, _loss, _withdrawn, _toBeWithdrawn);
    }

    function withdrawFromStaking(uint256 _amount) external {
        _withdraw(_amount);
    }

    function setStakingSlippage(uint256 _slippage) external {
        staking.setSlippage(_slippage);
    }

    function stakingBalance() external view returns(uint256) {
        return IERC20(asset).balanceOf(address(staking));
    }

    function stakingContract() external view returns(address) {
        return address(staking);
    }

    function _deposit() internal override {
        uint256 balance = IERC20(asset).balanceOf(address(this));
        staking.deposit(balance);
    }

    function _withdraw(uint256 _amount) internal override {
        staking.withdraw(_amount);
    }

    function _emergencyWithdraw() internal override {
        uint256 balance = IERC20(asset).balanceOf(address(staking));
        staking.withdraw(balance);
    }

    function _revokeAllowances() internal override {
        IERC20(asset).forceApprove(address(staking), 0);
    }

    function _giveAllowances() internal override {
        IERC20(asset).forceApprove(address(staking), type(uint256).max);
    }

    function _totalAssets() internal override view returns(uint256) {
        return IERC20(asset).balanceOf(address(staking));
    }
}

contract StakingMock {
    using SafeERC20 for IERC20;

    address asset;
    uint256 constant MAX_SLIPPAGE = 10_000;
    uint256 slippage;

    constructor(address _asset) {
        asset = _asset;
    }

    function deposit(uint256 _amount) external {
        IERC20(asset).safeTransferFrom(msg.sender, address(this), _amount);
    }

    function withdraw(uint256 _amount) external {
        uint256 lostAmount = Math.mulDiv(_amount, slippage, MAX_SLIPPAGE);
        IERC20(asset).safeTransfer(msg.sender, _amount - lostAmount);
        IERC20(asset).safeTransfer(address(42069), lostAmount);
    }

    function setSlippage(uint256 _slippage) external {
        slippage = _slippage;
    }
}