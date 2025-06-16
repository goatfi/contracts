// SPDX-License-Identifier: GNU AGPLv3

pragma solidity 0.8.27;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface ICurveGauge is IERC20 {
    function deposit(uint256 _value) external;
    function withdraw(uint256 _value) external;
    function claim_rewards() external;
}