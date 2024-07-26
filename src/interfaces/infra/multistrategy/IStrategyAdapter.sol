// SPDX-License-Identifier: GNU AGPLv3

pragma solidity >=0.8.20 <= 0.9.0;

interface IStrategyAdapter {
    /// @notice Emitted when the slippage limit is set.
    /// @param slippageLimit The new slippage limit in basis points (BPS).
    event SlippageLimitSet(uint256 slippageLimit);

    /// @notice Returns the address of the multistrategy this Strategy belongs to.
    function multistrategy() external view returns(address);

    /// @notice Returns the address of the token used tby this strategy.
    /// @dev it should be the same as the token used by the multistrategy.
    function baseAsset() external view returns(address);

    /// @notice Returns the current slippage limit in basis points (BPS).
    /// @dev The slippage limit is expressed in BPS, where 10,000 BPS equals 100%.
    /// @return The maximum allowable slippage in basis points.
    function slippageLimit() external view returns (uint256);

    /// @notice Sets the maximum allowable slippage limit for withdrawals.
    /// @dev Slippage limit is expressed in basis points (BPS), where 10,000 BPS equals 100%.
    /// This limit represents the tolerated difference between the expected withdrawal amount
    /// and the actual amount withdrawn from the strategy.
    /// @param _slippageLimit The maximum allowable slippage in basis points.
    function setSlippageLimit(uint256 _slippageLimit) external;

    /// @notice Requests a credit to the multistrategy. The multistrategy will send the
    /// maximum amount of credit available for this strategy.
    function requestCredit() external;

    /// @notice Sends a report to the Multistrategy of any gain or loss this strategy has
    ///         made along an amount to be withdrawn and be used for debt repayment.
    /// @dev Only the owner can call it
    /// @param _amountToWithdraw Amount that will be withdrawn from the strategy and will
    ///         be available for debt repayment.
    function sendReport(uint256 _amountToWithdraw) external;

    /// @notice Sends a report to the Multistrategy of any gain or loss this strategy has made.
    /// @dev This report wont withdraw any funds to reapay debt to the Multistrategy.
    /// Only the multistrategy can call it
    function askReport() external;

    /// @notice Sends a report to the Multistrategy after this strategy has been panicked.
    ///         Reporting any gains or loss based on the balance the could be emergency withdrawn
    /// @dev This function should only be called after a strategy has been retired.
    function sendReportPanicked() external;

    /// @notice Withdraws `baseAsset` from the strategy.
    /// @dev Only callable by the multistrategy.
    /// @param _amount Amount of tokens to withdraw from the strategy.
    function withdraw(uint256 _amount) external;

    /// @notice Returns the amount of `baseAsset` this strategy holds.
    function totalAssets() external view returns(uint256);

    /// @notice Starts the panic process for this strategy.
    /// The panic process consists of:
    ///     - Withdraw as much funds as possible from the underlying strategy.
    ///     - Report back to the multistrategy with the available funds.
    ///     - Revoke the allowance that this adapter has given to the underlying strategy.
    ///     - Pauses this contract.
    function panic() external;

    /// @notice Pauses the smart contract.
    /// @dev Functions that implement the `paused` modifier will revert when called.
    /// Guardians and Owner can call this function
    function pause() external;

    /// @notice Unpauses the smart contract.
    /// @dev Functions that implement the `paused` won't revert when called.
    /// Only the Owner can call this function
    function unpause() external;
}