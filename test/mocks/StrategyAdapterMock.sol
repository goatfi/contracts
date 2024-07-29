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
        address _baseAsset
    ) 
        StrategyAdapter(_multistrategy, _baseAsset) 
    {
        staking = new StakingMock(_baseAsset);
        IERC20(_baseAsset).forceApprove(address(staking), type(uint256).max);
    }

    function earn(uint256 _amount) external {
        IERC20Mock(baseAsset).mint(address(staking), _amount);
    }

    function lose(uint256 _amount) external {
        IERC20Mock(baseAsset).burn(address(staking), _amount);
    }

    function withdrawFromStaking(uint256 _amount) external {
        _withdraw(_amount);
    }

    function setStakingSlippage(uint256 _slippage) external {
        staking.setSlippage(_slippage);
    }

    function stakingBalance() external view returns(uint256) {
        return IERC20(baseAsset).balanceOf(address(staking));
    }

    function stakingContract() external view returns(address) {
        return address(staking);
    }

    function _deposit() internal override {
        uint256 balance = IERC20(baseAsset).balanceOf(address(this));
        staking.deposit(balance);
    }

    function _withdraw(uint256 _amount) internal override {
        staking.withdraw(_amount);
    }

    function _totalAssets() internal override view returns(uint256) {
         return IERC20(baseAsset).balanceOf(address(staking));
    }
}

contract StakingMock {
    using SafeERC20 for IERC20;

    address baseAsset;
    uint256 constant MAX_SLIPPAGE = 10_000;
    uint256 slippage;

    constructor(address _baseAsset) {
        baseAsset = _baseAsset;
    }

    function deposit(uint256 _amount) external {
        IERC20(baseAsset).safeTransferFrom(msg.sender, address(this), _amount);
    }

    function withdraw(uint256 _amount) external {
        uint256 lostAmount = Math.mulDiv(_amount, slippage, MAX_SLIPPAGE);
        IERC20(baseAsset).safeTransfer(msg.sender, _amount - lostAmount);
        IERC20(baseAsset).safeTransfer(address(42069), lostAmount);
    }

    function setSlippage(uint256 _slippage) external {
        slippage = _slippage;
    }
}