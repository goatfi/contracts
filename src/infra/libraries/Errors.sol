// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

/// @title Errors
/// @notice Library containing all custom errors the protocol may revert with.
library Errors {
    /*//////////////////////////////////////////////////////////////////////////
                                      GENERICS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Thrown when `msg.sender` is not the manager.
    error CallerNotManager(address caller);

    /// @notice Thrown when `msg.sender` is not a guardian.
    error CallerNotGuardian(address caller);

    /// @notice Thrown when `amount` is zero.
    error ZeroAmount(uint256 amount);

    /// @notice Thrown when setting an address to the zero address.
    error ZeroAddress();

    /// @notice Thrown when `currentBalance` is lower than `amount`.
    error InsufficientBalance(uint256 currentBalance, uint256 amount);

    /// @notice Thrown when `addr` is an unexpected address.
    error InvalidAddress(address addr);

    /*//////////////////////////////////////////////////////////////////////////
                                    MULTISTRATEGY
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Thrown when performing an action on a non-active strategy.
    error StrategyNotActive(address strategy);

    /// @notice Thrown when performing an action on an active strategy.
    error StrategyAlreadyActive(address strategy);

    /// @notice Thrown when a strategy is reporting a gain and a loss simultaneously.
    error GainLossMismatch();

    /// @notice Thrown when a deposit would exceed the depositLimit
    error DepositLimit();

    /// @notice Thrown when the owner tries to set a fee above the maximum permitted fee.
    error ExcessiveFee(uint256 fee);

    /// @notice Thrown when the debtRatio of a strategy or a multistrategy is above 100%.
    error DebtRatioAboveMaximum(uint256 debtRatio);

    /// @notice Thrown when trying to remove a strategy from `withdrawOrder` that still has outstanding debt.
    error StrategyWithOutstandingDebt();

    /// @notice Thrown when minDebtDelta is above maxDebtDelta or maxDebtDelta is below minDebtDelta.
    error InvalidDebtDelta();

    /// @notice Thrown when a strategy is reporting a loss higher than its total debt.
    error InvalidStrategyLoss();

    /// @notice Thrown when there is non-Zero Address following a Zero Address in withdrawOrder.
    error InvalidWithdrawOrder();

    /// @notice Thrown when trying to add a new strategy to the multistrategy but it already reached the
    /// maximum amount of strategies.
    error MaximumAmountStrategies();

    /// @notice Thrown when trying to remove a strategy that has a `debtRatio` greater than 0.
    error StrategyNotRetired();

    /// @notice Thrown when there isn't enough liquidity to cover a withdraw
    /// @param assets The amount of assets requested.
    /// @param liquidity The current liquidity available in the contract.
    error InsufficientLiquidity(uint256 assets, uint256 liquidity);

    /// @notice Thrown when depositing / minting on a retired multistrategy.
    error Retired();

    /*//////////////////////////////////////////////////////////////////////////
                                STRATEGY ADAPTER
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Thrown when the caller is not the Multistrategy.
    error CallerNotMultistrategy(address caller);

    /// @notice Thrown when the `_asset` parameter on the constructor doesn't match 
    /// the `deposit` token on Multistrategy.
    error AssetMismatch(address multAsset, address stratAsset);

    /// @notice Thrown when the requested slippage limit exceeds the maximum permitted value.
    /// @param slippageLimit The slippage limit in basis points (BPS).
    error SlippageLimitExceeded(uint256 slippageLimit);

    /// @notice Thrown when the actual slippage exceeds the allowed slippage.
    /// @param amount0 The expected amount after accounting for allowed slippage.
    /// @param amount1 The actual amount obtained.
    error SlippageCheckFailed(uint256 amount0, uint256 amount1);

    /*//////////////////////////////////////////////////////////////////////////
                            STRATEGY ADAPTER HARVESTABLE
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Thrown when the reward added is not valid according to `_verifyRewardToken`
    error InvalidRewardToken(address rewardToken);

    /// @notice Thrown when this adapter is being harvested but there are no rewards defined
    /// in the rewards array.
    error NoRewards();

    /*//////////////////////////////////////////////////////////////////////////
                                    ERC-4626
    //////////////////////////////////////////////////////////////////////////*/

    /**
     * @dev Attempted to deposit more assets than the max amount for `receiver`.
     */
    error ERC4626ExceededMaxDeposit(address receiver, uint256 assets, uint256 max);

    /**
     * @dev Attempted to mint more shares than the max amount for `receiver`.
     */
    error ERC4626ExceededMaxMint(address receiver, uint256 shares, uint256 max);

    /**
     * @dev Attempted to withdraw more assets than the max amount for `receiver`.
     */
    error ERC4626ExceededMaxWithdraw(address owner, uint256 assets, uint256 max);

    /**
     * @dev Attempted to redeem more shares than the max amount for `receiver`.
     */
    error ERC4626ExceededMaxRedeem(address owner, uint256 shares, uint256 max);
}