// SPDX-License-Identifier: GNU AGPLv3

pragma solidity ^0.8.27;

interface IStrategyAdapterHarvestable {
    /// @notice Emitted when the adapter successfully harvests rewards.
    /// @param caller The address of the caller who triggered the harvest.
    /// @param amountHarvested The amount of `want` tokens harvested.
    /// @param totalAssets The total assets held by the adapter after the harvest.
    event AdapterHarvested(address caller, uint256 amountHarvested, uint256 totalAssets);

    /// @notice Emitted when the swapper contract is updated.
    /// @param newSwapper The address of the new swapper contract.
    event SwapperUpdated(address newSwapper);

    /// @notice Returns the amount of different reward tokens existent in the `rewards` array
    function rewardsLength() external view returns (uint256);

    /// @notice Harvests rewards, swaps them to WETH, and then to the desired asset.
    /// @dev This function claims rewards, swaps them to WETH, and then converts WETH to the `want` token.
    function harvest() external;

    /// @notice Adds a new reward token to be claimed.
    /// @param token The address of the reward token to add.
    /// @dev The token must not be the same as `want` or `weth`.
    function addReward(address token) external;

    /// @notice Resets the list of reward tokens.
    /// @dev This function removes all reward tokens and revokes their approvals.
    function resetRewards() external;

    /// @notice Sets the minimum amount of a reward token required for swapping.
    /// @param token The address of the reward token.
    /// @param minAmount The minimum amount of the token required for swapping.
    function setRewardMinimumAmount(address token, uint256 minAmount) external;

    /// @notice Updates the swapper contract used for swapping tokens.
    /// @param swapper The address of the new swapper contract.
    /// @dev This function revokes approvals from the old swapper and grants them to the new swapper.
    function updateSwapper(address swapper) external;

    /// @notice It will transfer all the reward token balance to the owner.
    /// @param _rewardToken The reward token to rescue
    function rescueRewards(address _rewardToken) external;
}