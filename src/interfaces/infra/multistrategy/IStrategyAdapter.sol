// SPDX-License-Identifier: GNU AGPLv3

pragma solidity >=0.8.20 <= 0.9.0;

interface IStrategyAdapter {

    /// @notice Returns the address of the multistrategy this Strategy belongs to.
    function multistrategy() external view returns(address);

    /// @notice Returns the address of the token used tby this strategy.
    /// @dev it should be the same as the token used by the multistrategy.
    function depositToken() external view returns(address);

    /// @notice Requests a credit to the multistrategy. The multistrategy will send the
    /// maximum amount of credit available for this strategy.
    function requestCredit() external;

    /// @notice Sends a report to the Multistrategy of any gain or loss this strategy has made.
    /// @dev This report wont withdraw any funds to reapay debt to the Multistrategy.
    function sendReport() external;

    /// @notice Sends a report to the Multistrategy of any gain or loss this strategy has
    ///         made along an amount to be withdrawn and be used for debt repayment.
    /// @param amountToWithdraw Amount that will be withdrawn from the strategy and will
    ///         be available for debt repayment.
    function sendReport(uint256 amountToWithdraw) external;

    /// @notice Withdraws `depositToken` from the strategy.
    /// @dev Only callable by the multistrategy.
    /// @param amount Amount of tokens to withdraw from the strategy.
    function withdraw(uint256 amount) external;

    /// @notice Returns the amount of `depositToken` this strategy holds.
    function totalAssets() external view returns(uint256);
}