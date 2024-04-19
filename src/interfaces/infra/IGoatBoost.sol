// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IGoatBoost {
    // Variables
    function stakedToken() external view returns (IERC20);
    function rewardToken() external view returns (IERC20);
    function duration() external view returns (uint256);
    function owner() external view returns (address);
    function manager() external view returns (address);
    function treasury() external view returns (address);
    function treasuryFee() external view returns (uint256);

    // Functions
    function initialize(
        address _stakedToken,
        address _rewardToken,
        uint256 _duration,
        address _manager,
        address _treasury
    ) external;
    function transferOwnership(address owner) external;
    function setTreasuryFee(uint256 _fee) external;
}