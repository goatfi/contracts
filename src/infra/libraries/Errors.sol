// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

/// @title Errors
/// @notice Library containing all custom errors the protocol may revert with.
library Errors {
    /*//////////////////////////////////////////////////////////////////////////
                                      GENERICS
    //////////////////////////////////////////////////////////////////////////*/

    /**
     * @notice Thrown when `msg.sender` is not the manager.
     * @param caller The address that attempted to call the restricted function.
     */
    error CallerNotManager(address caller);

    /**
     * @notice Thrown when `msg.sender` is not a guardian.
     * @param caller The address that attempted to call the restricted function.
     */
    error CallerNotGuardian(address caller);

    /**
     * @notice Thrown when `amount` is zero.
     * @param amount The zero value that caused the operation to fail.
     */
    error ZeroAmount(uint256 amount);

    /**
     * @notice Thrown when setting an address to the zero address.
     */
    error ZeroAddress();

    /**
     * @notice Thrown when `currentBalance` is lower than `amount`.
     * @param currentBalance The available balance at the time of the operation.
     * @param amount The required amount that exceeded the available balance.
     */
    error InsufficientBalance(uint256 currentBalance, uint256 amount);

    /**
     * @notice Thrown when `addr` is an unexpected or invalid address.
     * @param addr The address that failed validation.
     */
    error InvalidAddress(address addr);

    /*//////////////////////////////////////////////////////////////////////////
                                    MULTISTRATEGY
    //////////////////////////////////////////////////////////////////////////*/

    /**
     * @notice Thrown when performing an action on a non-active strategy.
     * @param strategy The address of the strategy that is inactive.
     */
    error StrategyNotActive(address strategy);

    /**
     * @notice Thrown when performing an action on an active strategy.
     * @param strategy The address of the strategy that is already active.
     */
    error StrategyAlreadyActive(address strategy);

    /**
     * @notice Thrown when a strategy reports both a gain and a loss simultaneously.
     */
    error GainLossMismatch();

    /**
     * @notice Thrown when a deposit would exceed the configured deposit limit.
     */
    error DepositLimit();

    /**
     * @notice Thrown when the owner tries to set a fee above the maximum permitted fee.
     * @param fee The fee value that exceeded the allowed maximum.
     */
    error ExcessiveFee(uint256 fee);

    /**
     * @notice Thrown when the debtRatio of a strategy or a multistrategy is above 100%.
     * @param debtRatio The current debt ratio that exceeds the 100% threshold.
     */
    error DebtRatioAboveMaximum(uint256 debtRatio);

    /**
     * @notice Thrown when trying to remove a strategy from `withdrawOrder` that still has outstanding debt.
     */
    error StrategyWithOutstandingDebt();

    /**
     * @notice Thrown when `minDebtDelta` is greater than `maxDebtDelta`, or vice versa.
     * @dev Enforces correct configuration of debt rebalancing thresholds.
     */
    error InvalidDebtDelta();

    /**
     * @notice Thrown when a strategy reports a loss greater than its total allocated debt.
     */
    error InvalidStrategyLoss();

    /**
     * @notice Thrown when there is a non-zero address following a zero address in `withdrawOrder`.
     */
    error InvalidWithdrawOrder();

    /**
     * @notice Thrown when trying to add a new strategy to the multistrategy
     * but the maximum allowed number of strategies has already been reached.
     */
    error MaximumAmountStrategies();

    /**
     * @notice Thrown when trying to remove a strategy that has a non-zero `debtRatio`.
     */
    error StrategyNotRetired();

    /**
     * @notice Thrown when attempting to deposit or mint on a retired multistrategy.
     */
    error Retired();

    /*//////////////////////////////////////////////////////////////////////////
                                STRATEGY ADAPTER
    //////////////////////////////////////////////////////////////////////////*/

    /**
     * @notice Thrown when the caller is not the Multistrategy.
     * @param caller The address that attempted to call the restricted function.
     */
    error CallerNotMultistrategy(address caller);

    /**
     * @notice Thrown when the `_asset` parameter in the constructor doesn't match 
     * the deposit token defined by the Multistrategy contract.
     * @param multAsset The asset address expected by the Multistrategy.
     * @param stratAsset The asset address provided to the strategy.
     */
    error AssetMismatch(address multAsset, address stratAsset);

    /**
     * @notice Thrown when the requested slippage limit exceeds the maximum permitted value.
     * @param slippageLimit The slippage limit in basis points (BPS) that exceeded the allowed maximum.
     */
    error SlippageLimitExceeded(uint256 slippageLimit);

    /**
     * @notice Thrown when the actual slippage exceeds the allowed slippage threshold.
     * @param amount0 The minimum expected amount based on allowed slippage.
     * @param amount1 The actual amount received or returned.
     */
    error SlippageCheckFailed(uint256 amount0, uint256 amount1);

    /*//////////////////////////////////////////////////////////////////////////
                            STRATEGY ADAPTER HARVESTABLE
    //////////////////////////////////////////////////////////////////////////*/

    /**
     * @notice Thrown when the reward added is not valid according to `_verifyRewardToken`.
     * @param rewardToken The address of the reward token that failed validation.
     */
    error InvalidRewardToken(address rewardToken);

    /**
     * @notice Thrown when this adapter is being harvested but there are no rewards defined
     * in the rewards array.
     */
    error NoRewards();

    /**
     * @notice Thrown when a gauge is invalid.
     */
    error InvalidGauge();

    /*//////////////////////////////////////////////////////////////////////////
                                    ERC-4626
    //////////////////////////////////////////////////////////////////////////*/

    /**
     * @notice Thrown when attempted to deposit more assets than the max amount for `receiver`.
     * @dev Reverts when `assets` is greater than `maxDeposit(receiver)`.
     * @param receiver The address for which the deposit is being attempted.
     * @param assets The number of assets the user attempted to deposit.
     * @param max The maximum number of assets that can be deposited for the receiver.
     */
    error ERC4626ExceededMaxDeposit(address receiver, uint256 assets, uint256 max);

    /**
     * @notice Thrown when attempted to mint more shares than the max amount for `receiver`.
     * @dev Reverts when `shares` is greater than `maxMint(receiver)`.
     * @param receiver The address for which the minting is being attempted.
     * @param shares The number of shares the user attempted to mint.
     * @param max The maximum number of shares that can be minted for the receiver.
     */
    error ERC4626ExceededMaxMint(address receiver, uint256 shares, uint256 max);

    /**
     * @notice Thrown when attempted to withdraw more assets than the max amount for `owner`.
     * @dev Reverts when `assets` is greater than `maxWithdraw(owner)`.
     * @param owner The address that owns the shares being redeemed for assets.
     * @param assets The number of assets the user attempted to withdraw.
     * @param max The maximum number of assets that can be withdrawn by the owner.
     */
    error ERC4626ExceededMaxWithdraw(address owner, uint256 assets, uint256 max);

    /**
     * @notice Thrown when attempted to redeem more shares than the max amount for `owner`.
     * @dev Reverts when `shares` is greater than `maxRedeem(owner)`.
     * @param owner The address that owns the shares to be redeemed.
     * @param shares The number of shares the user attempted to redeem.
     * @param max The maximum number of shares that can be redeemed by the owner.
     */
    error ERC4626ExceededMaxRedeem(address owner, uint256 shares, uint256 max);
}