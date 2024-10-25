// SPDX-License-Identifier: GNU AGPLv3

pragma solidity >=0.8.20 <= 0.9.0;

import { IStrategyAdapter } from "interfaces/infra/multistrategy/IStrategyAdapter.sol";

interface IOwnable {
    function transferOwnership(address newOwner) external;
}

interface IPausable {
    function paused() external view returns(bool);
}

interface IStrategyAdapterMock is IStrategyAdapter {
    function earn(uint256 _amount) external;
    function lose(uint256 _amount) external;
    function tryWithdraw(uint256 _amount) external;
    function setStakingSlippage(uint256 _slippage) external;
    function stakingBalance() external view returns(uint256);
    function stakingContract() external view returns(address);
    function calculateGainAndLoss(uint256 _currentAssets) external view returns(uint256, uint256);
    function calculateAmountToBeWithdrawn(uint256 _repayAmount, uint256 _strategyGain) external view returns(uint256);
    function calculateGainAndLossAfterSlippage(
        uint256 _gain, 
        uint256 _loss, 
        uint256 _withdrawn, 
        uint256 _toBeWithdrawn
        ) external pure returns (uint256, uint256);
}