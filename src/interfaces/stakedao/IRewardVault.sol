// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";

/// @title IRewardVault
/// @notice Interface for the RewardVault contract
interface IRewardVault is IERC4626 {
    function ACCOUNTANT() external view returns (address);

    function claim(address[] calldata tokens, address receiver) external returns (uint256[] memory amounts);

    function gauge() external view returns (address _gauge);

    function getRewardTokens() external view returns (address[] memory);

    function rewardPerToken(address token) external view returns (uint128);

    function earned(address account, address token) external view returns (uint128);

    function isRewardToken(address rewardToken) external view returns (bool);
}