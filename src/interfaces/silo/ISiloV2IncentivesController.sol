// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ISiloV2IncentivesController {
    function claimRewards(address to) external;
    function getAllProgramsNames() external view returns (string[] memory);
    function getRewardsBalance(address _user, string memory _programName) external view returns (uint256);
}