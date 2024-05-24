// SPDX-License-Identifier: MIT

pragma solidity >=0.8.20 <= 0.9.0;

interface IStrategyWrapper {

    /// @notice Returns the address of the multistrategy this Strategy belongs to.
    function multistrategy() external view returns(address);

    /// @notice Returns the address of the token used tby this strategy.
    /// @dev it should be the same as the token used by the multistrategy.
    function depositToken() external view returns(address);

    /// @notice Deposits `depositToken` into the strategy.
    /// @dev Only callable by the multistrategy.
    /// @param amount Amount of tokens to deposit in the strategy.
    function deposit(uint256 amount) external;

    /// @notice Withdraws `depositToken` from the strategy.
    /// @dev Only callable by the multistrategy.
    /// @param amount Amount of tokens to withdraw from the strategy.
    function withdraw(uint256 amount) external;

    /// @notice Returns the amount of `depositToken` this strategy holds.
    function totalAssets() external view returns(uint256);
}