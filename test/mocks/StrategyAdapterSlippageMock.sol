// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IERC20, SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20Mock } from "interfaces/common/IERC20Mock.sol";
import { StrategyAdapter } from "src/abstracts/StrategyAdapter.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

contract StrategyAdapterSlippageMock is StrategyAdapter {
    using SafeERC20 for IERC20;

    StakingMockSlippage staking;

    constructor(
        address _multistrategy,
        address _depositToken,
        uint256 _slippage
    ) 
        StrategyAdapter(_multistrategy, _depositToken) 
    {
        staking = new StakingMockSlippage(_depositToken, _slippage);
        IERC20(_depositToken).forceApprove(address(staking), type(uint256).max);
    }

    function earn(uint256 _amount) external {
        IERC20Mock(depositToken).mint(address(staking), _amount);
    }

    function lose(uint256 _amount) external {
        IERC20Mock(depositToken).burn(address(staking), _amount);
    }

    function withdrawFromStaking(uint256 _amount) external {
        _withdraw(_amount);
    }

    function _deposit() internal override {
        uint256 balance = IERC20(depositToken).balanceOf(address(this));
        staking.deposit(balance);
    }

    function _withdraw(uint256 _amount) internal override {
        staking.withdraw(_amount);
    }

    function _totalAssets() internal override view returns(uint256) {
         return IERC20(depositToken).balanceOf(address(staking));
    }
}

contract StakingMockSlippage {
    using SafeERC20 for IERC20;

    address depositToken;
    uint256 constant MAX_SLIPPAGE = 10_000;
    uint256 slippage;

    constructor(address _depositToken, uint256 _slippage) {
        depositToken = _depositToken;
        slippage = _slippage;
    }

    function deposit(uint256 _amount) external {
        IERC20(depositToken).safeTransferFrom(msg.sender, address(this), _amount);
    }

    function withdraw(uint256 _amount) external {
        uint256 lostAmount = Math.mulDiv(_amount, slippage, MAX_SLIPPAGE);
        IERC20(depositToken).safeTransfer(msg.sender, _amount - lostAmount);
        IERC20(depositToken).safeTransfer(address(42069), lostAmount);
    }
}