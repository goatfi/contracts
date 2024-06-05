// SPDX-License-Identifier: GNU AGPLv3

pragma solidity >=0.8.20 <= 0.9.0;

import { IMultistrategyAdminable } from "interfaces/infra/multistrategy/IMultistrategyAdminable.sol";
import { MStrat } from "src/types/DataTypes.sol";

interface IMultistrategyManageable is IMultistrategyAdminable {
    /// @notice Emitted when the protocol fee recipient is set.
    /// @param protocolFeeRecipient The address that will receive the protocol fee.
    event ProtocolFeeRecipientSet(address indexed protocolFeeRecipient);

    /// @notice Emitted when the performance fee is set.
    /// @param performanceFee The new performance fee value.
    event PerformanceFeeSet(uint256 performanceFee);

    /// @notice Emitted when the deposit limit is set.
    /// @param depositLimit The new deposit limit value.
    event DepositLimitSet(uint256 depositLimit);

    /// @notice Emitted when the debt ratio for a specific strategy is set.
    /// @param strategy The address of the strategy whose debt ratio was updated.
    /// @param debtRatio The new debt ratio value for the specified strategy.
    event StrategyDebtRatioSet(address indexed strategy, uint256 debtRatio);

    /// @notice Emitted when the minimum debt delta for a specific strategy is set.
    /// @param strategy The address of the strategy whose minimum debt delta was updated.
    /// @param minDebtDelta The new minimum debt delta value for the specified strategy.
    event StrategyMinDebtDeltaSet(address indexed strategy, uint256 minDebtDelta);

    /// @notice Emitted when the maximum debt delta for a specific strategy is set.
    /// @param strategy The address of the strategy whose maximum debt delta was updated.
    /// @param maxDebtDelta The new maximum debt delta value for the specified strategy.
    event StrategyMaxDebtDeltaSet(address indexed strategy, uint256 maxDebtDelta);

    /// @notice Emitted when a new strategy is added.
    /// @param strategy The address of the newly added strategy.
    event StrategyAdded(address indexed strategy);

    /// @notice Emitted when a strategy is revoked.
    /// @param strategy The address of the revoked strategy.
    event StrategyRevoked(address indexed strategy);

    /// @notice Emitted when a strategy is removed.
    /// @param strategy The address of the removed strategy.
    event StrategyRemoved(address indexed strategy);

    /// @notice Address of the token used in the Multistrategy.
    function depositToken() external view returns(address);

    /// @notice Address that will recieve performance fee.
    function protocolFeeRecipient() external view returns(address);

    /// @notice Fee on the yield generated (in BPS).
    /// @dev Performance fee is taken on `strategyReport()` funciton on the Multistrategy contract.
    function performanceFee() external view returns(uint256);

    /// @notice Limit for total assets the multistrategy can hold.
    function depositLimit() external view returns(uint256);

    /// @notice Debt ratio of the multistrategy across all strategies (in BPS).
    /// @dev The debt ratio cannot exceed 10_000 BPS (100 %).
    function debtRatio() external view returns(uint256);

    /// @notice Amount of tokens that the strategies have borrowed in total.
    function totalDebt() external view returns(uint256);

    /// @notice Amount of active strategies.
    function activeStrategies() external view returns(uint8);

    /// @notice Returns the withdraw order.
    function getWithdrawOrder() external view returns(address[] memory);

    /// @notice Returns the strategy params of `strategy`
    /// @param strategy Address of the strategy the it will returns the parameters of.
    function getStrategyParameters(address strategy) external view returns(MStrat.StrategyParams calldata);

    /// @notice Sets the recipient address of the performance fee.
    /// @dev Emits a `SetProtocolFeeRecipient` event.
    /// @param protocolFeeRecipient Address that will receive the fees.
    function setProtocolFeeRecipient(address protocolFeeRecipient) external;

    /// @notice Sets the performance fee in BPS.
    /// @dev Reverts if `performanceFee` is above MAX_PERFORMANCE_FEE
    /// @dev Emits a `SetPerformanceFee` event.
    /// @param performanceFee New perfomance fee.
    function setPerformanceFee(uint256 performanceFee) external;

    /// @notice Sets the deposit limit.
    /// @dev Emits a `SetDepositLimit` event.
    /// @param depositLimit New deposit limit.
    function setDepositLimit(uint256 depositLimit) external;

    /// @notice Sets the withdraw order. First position in the array will be the first strategy that it will get the funds withdrawn
    /// @dev It will revert if a strategy in the array is not active or if the array contains duplicate addresses.
    /// @param strategies Array of strategy addresses
    function setWithdrawalOrder(address[] memory strategies) external;

    /// @notice Adds a strategy to the multistrategy.
    /// @dev The strategy will be appended to `withdrawOrder`.
    /// @param strategy The address of the strategy.
    /// @param debtRatio The share of total assets in the Multistrategy this strategy will have access to.
    /// @param minDebtDelta Lower limit on the increase of debt.
    /// @param maxDebtDelta Upper limit on the increase of debt.
    function addStrategy(
        address strategy,
        uint256 debtRatio,
        uint256 minDebtDelta,
        uint256 maxDebtDelta
    ) external;

    /// @notice Sets the strategy debtRatio to 0, which prevents any further deposits into the strategy.
    /// @dev Retiring a strategy will set the approval of `depositToken` to the retiried strategy to 0.
    /// @param strategy The address of the strategy that will be retired.
    function retireStrategy(address strategy) external;

    /// @notice Removes a strategy from `withdrawOrder`.
    /// @param strategy The address of the strategy that will be removed.
    function removeStrategy(address strategy) external;

    /// @notice Change the debt ratio of a strategy.
    /// @param strategy Address of the strategy.
    /// @param debtRatio New debt ratio.
    function setStrategyDebtRatio(address strategy, uint256 debtRatio) external;

    /// @notice Change the minimum amount of debt a strategy can take.
    /// @dev Used to limit the minimum amount of debt a strategy should take. 
    ///      Taking a small credit wouldn't be optimal gas-wise.
    /// @param strategy Address of the strategy.
    /// @param minDebtDelta Lower limit of the change of debt.
    function setStrategyMinDebtDelta(address strategy, uint256 minDebtDelta) external;

    /// @notice Change the maximum amount of debt a strategy can take at once.
    /// @dev Used to protect large debt repayments or withdraws. Risks are IL, or low liquidity.
    /// @param strategy Address of the strategy.
    /// @param maxDebtDelta Upper limit of the change of debt.
    function setStrategyMaxDebtDelta(address strategy, uint256 maxDebtDelta) external;
}