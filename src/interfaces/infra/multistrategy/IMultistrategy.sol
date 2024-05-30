// SPDX-License-Identifier: GNU AGPLv3

pragma solidity >=0.8.20 <= 0.9.0;

interface IMultistrategy {
    /// @notice Emitted when an account has made a deposit.
    /// @param amount Amount of depositToken that has been deposited.
    /// @param recipient Address that will receive the receipt tokens.
    event Deposit(uint256 amount, address indexed recipient);

    /// @notice Emitted when an account has made a withdraw.
    /// @param amount Amount of shares that have been withdrawn.
    event Withdraw(uint256 amount);

    /// @notice Emitted when a strategy has requested a credit.
    /// @param strategy Address of the strategy that requested the credit.
    /// @param amount Amount of credit that has been granted to the strategy.
    event CreditRequested(address indexed strategy, uint256 amount);

    /// @notice Emitted when a strategy has submitted a report.
    /// @param strategy Address of the strategy that has submitted the report.
    /// @param debtRepaid Amount of debt that has been repaid by the strategy.
    /// @param gain Amount of gain that the strategy has reported.
    /// @param loss Amount of loss that the strategy has reported.
    event StrategyReported(address indexed strategy, uint256 debtRepaid, uint256 gain, uint256 loss);

    /// @notice Timestamp of the last report made by a strategy.
    function lastReport() external view returns(uint256);

    /// @notice Amount of tokens that are locked as "locked profit" and can't be withdrawn.
    function lockedProfit() external view returns(uint256);

    /// @notice Rate at which the locked profit gets unlocked per second.
    function lockedProfitDegradation() external view returns(uint256);

    /// @notice Returns the amount of `depositToken` this Multistrategy holds.
    function totalAssets() external returns(uint256);

    /// @notice Returns the value of a share in `depositToken` value.
    function pricePerShare() external view returns(uint256);

    /// @notice Returns the amount of tokens a strategy can borrow from this Multistrategy.
    /// @param strategy Address of the strategy we want to know the credit available for.
    function creditAvailable(address strategy) external view returns(uint256);

    /// @notice Returns the excess of debt a strategy currently holds.
    /// @param strategy Address of the strategy we want to know if it has any debt excess.
    function debtExcess(address strategy) external view returns(uint256);

    /// @notice Returns the total debt of `strategy`.
    /// @param strategy Address of the strategy we want to know the `totalDebt`.
    function strategyTotalDebt(address strategy) external view returns(uint256);

    /// @notice Deposit an amount of `depositToken` and mint Multistrategy shares to recipient.
    /// @param amount Amount of `depositToken` the caller wants to deposit.
    /// @param recipient Address that will receive the Multistrategy shares.
    function deposit(uint256 amount, address recipient) external;

    /// @notice Deposit an amount of `depositToken` and mint Multistrategy shares to `msg.sender`.
    /// @param amount Amount of `depositToken` the caller wants to deposit.
    function deposit(uint256 amount) external;

    /// @notice Withdraw an amount of shares in exchange for an amount of `depositToken`.
    /// @param amount Amount of Multistrategy shares.
    function withdraw(uint256 amount) external;

    /// @notice Withdraw all the shares of the caller in exchange for an amount of `depositToken`.
    function withdrawAll() external;
    
    /// @notice Send the available credit of the caller to the caller.
    /// @dev Reverts if the caller is *NOT* an active strategy
    function requestCredit() external;

    /// @notice Report the profit or loss of a strategy along any debt the strategy is willing to pay back.
    /// @dev Can only be called by an active strategy.
    /// @param _debtRepayment Amount that the strategy will send back to the multistrategy as debt repayment.
    /// @param _profit Amount that the strategy has realised as a gain since the last report and will send it
    ///                to this Multistrategy as earnings. 
    /// @param _loss Amount that the strategy has realised as a loss since the last report. 
    function strategyReport(uint256 _debtRepayment, uint256 _profit, uint256 _loss) external;

    /// @notice Emergency function to rescue tokens not related to the Multistrategy sent to the contract by mistake.
    /// @param token Address of the token that will be rescued.
    /// @param recipient Address of who will receive the tokens.
    function rescueToken(address token, address recipient) external;
}