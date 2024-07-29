// SPDX-License-Identifier: GNU AGPLv3

pragma solidity >=0.8.20 <= 0.9.0;

import { IStrategyAdapter } from "interfaces/infra/multistrategy/IStrategyAdapter.sol";

interface IOwnable {
    function transferOwnership(address newOwner) external;
}

interface IPausable {
    function paused() external view returns(bool);
}

interface IStrategyAdapterMock {
    function earn(uint256 _amount) external;
    function lose(uint256 _amount) external;
    function stakingBalance() external view returns(uint256);
    function stakingContract() external view returns(address);
}

interface IStrategyAdapterSlippage is IStrategyAdapter {
    function setStakingSlippage(uint256 slippage) external;
}