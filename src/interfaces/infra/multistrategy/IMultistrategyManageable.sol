// SPDX-License-Identifier: GNU AGPLv3

pragma solidity ^0.8.27;

import { IMultistrategyAdminable } from "interfaces/infra/multistrategy/IMultistrategyAdminable.sol";
import { MStrat } from "src/types/DataTypes.sol";

interface IMultistrategyManageable is IMultistrategyAdminable {
    /// @notice Emitted when the protocol fee recipient is set.
    /// @param _protocolFeeRecipient The address that will receive the protocol fee.
    event ProtocolFeeRecipientSet(address indexed _protocolFeeRecipient);

    /// @notice Emitted when the performance fee is set.
    /// @param _performanceFee The new performance fee value.
    event PerformanceFeeSet(uint256 _performanceFee);

    /// @notice Emitted when the deposit limit is set.
    /// @param _depositLimit The new deposit limit value.
    event DepositLimitSet(uint256 _depositLimit);

    /// @notice Emitted when the slippage limit is set.
    /// @param _slippageLimit The new slippage limit value.
    event SlippageLimitSet(uint256 _slippageLimit);

    /// @notice Emitted when a new withdrawal order has been set.
    event WithdrawOrderSet();

    /// @notice Emitted when the debt ratio for a specific strategy is set.
    /// @param _strategy The address of the strategy whose debt ratio was updated.
    /// @param _debtRatio The new debt ratio value for the specified strategy.
    event StrategyDebtRatioSet(address indexed _strategy, uint256 _debtRatio);

    /// @notice Emitted when the minimum debt delta for a specific strategy is set.
    /// @param _strategy The address of the strategy whose minimum debt delta was updated.
    /// @param _minDebtDelta The new minimum debt delta value for the specified strategy.
    event StrategyMinDebtDeltaSet(address indexed _strategy, uint256 _minDebtDelta);

    /// @notice Emitted when the maximum debt delta for a specific strategy is set.
    /// @param _strategy The address of the strategy whose maximum debt delta was updated.
    /// @param _maxDebtDelta The new maximum debt delta value for the specified strategy.
    event StrategyMaxDebtDeltaSet(address indexed _strategy, uint256 _maxDebtDelta);

    /// @notice Emitted when a new strategy is added.
    /// @param _strategy The address of the newly added strategy.
    event StrategyAdded(address indexed _strategy);

    /// @notice Emitted when a strategy is retired.
    /// @param _strategy The address of the retired strategy.
    event StrategyRetired(address indexed _strategy);

    /// @notice Emitted when a strategy is removed.
    /// @param _strategy The address of the removed strategy.
    event StrategyRemoved(address indexed _strategy);

    /// @notice Emitted when the deposits into this multistrategy are paused.
    event MultistrategyRetired();

    /// @notice Address that will receive performance fee.
    function protocolFeeRecipient() external view returns (address);

    /// @notice Fee on the yield generated (in BPS).
    /// @dev Performance fee is taken on `strategyReport()` function on the Multistrategy contract.
    function performanceFee() external view returns (uint256);

    /// @notice Limit for total assets the multistrategy can hold.
    function depositLimit() external view returns (uint256);

    /// @notice Debt ratio of the multistrategy across all strategies (in BPS).
    /// @dev The debt ratio cannot exceed 10_000 BPS (100 %).
    function debtRatio() external view returns (uint256);

    /// @notice Amount of tokens that the strategies have borrowed in total.
    function totalDebt() external view returns (uint256);

    /// @notice Returns the current slippage limit in basis points (BPS).
    /// @dev The slippage limit is expressed in BPS, where 10,000 BPS equals 100%.
    function slippageLimit() external view returns (uint256);

    /// @notice Amount of active strategies.
    function activeStrategies() external view returns (uint8);

    /// @notice Returns true if multistrategy has been retired. 
    function retired() external view returns (bool);

    /// @notice Returns the withdraw order.
    function getWithdrawOrder() external view returns (address[] memory);

    /// @notice Returns the strategy params of `strategy`
    /// @param _strategy Address of the strategy the it will returns the parameters of.
    function getStrategyParameters(address _strategy) external view returns (MStrat.StrategyParams calldata);

    /// @notice Sets the recipient address of the performance fee.
    /// @dev Emits a `SetProtocolFeeRecipient` event.
    /// @param _protocolFeeRecipient Address that will receive the fees.
    function setProtocolFeeRecipient(address _protocolFeeRecipient) external;

    /// @notice Sets the performance fee in BPS.
    /// @dev Reverts if `performanceFee` is above MAX_PERFORMANCE_FEE
    /// @dev Emits a `SetPerformanceFee` event.
    /// @param _performanceFee New performance fee.
    function setPerformanceFee(uint256 _performanceFee) external;

    /// @notice Sets the deposit limit.
    /// @dev Emits a `SetDepositLimit` event.
    /// @param _depositLimit New deposit limit.
    function setDepositLimit(uint256 _depositLimit) external;

    /// @notice Sets the slippage limit of this Multistrategy.
    /// @dev The slippage limit is expressed in BPS, where 10,000 BPS equals 100%.
    /// @param _slippageLimit New slippage limit.
    function setSlippageLimit(uint256 _slippageLimit) external;

    /// @notice Sets the withdraw order. First position in the array will be the first strategy that it will get the funds withdrawn
    /// @dev It will revert if a strategy in the array is not active or if the array contains duplicate addresses.
    /// @param _strategies Array of strategy addresses
    function setWithdrawOrder(address[] memory _strategies) external;

    /// @notice Adds a strategy to the multistrategy.
    /// @dev The strategy will be appended to `withdrawOrder`.
    /// @param _strategy The address of the strategy.
    /// @param _debtRatio The share of total assets in the Multistrategy this strategy will have access to.
    /// @param _minDebtDelta Lower limit on the increase of debt.
    /// @param _maxDebtDelta Upper limit on the increase of debt.
    function addStrategy(
        address _strategy,
        uint256 _debtRatio,
        uint256 _minDebtDelta,
        uint256 _maxDebtDelta
    ) external;

    /// @notice Sets the strategy debtRatio to 0, which prevents any further deposits into the strategy.
    /// @dev Retiring a strategy will set the approval of `asset` to the retired strategy to 0.
    /// @param _strategy The address of the strategy that will be retired.
    function retireStrategy(address _strategy) external;

    /// @notice Removes a strategy from `withdrawOrder`.
    /// @param _strategy The address of the strategy that will be removed.
    function removeStrategy(address _strategy) external;

    /// @notice Change the debt ratio of a strategy.
    /// @param _strategy Address of the strategy.
    /// @param _debtRatio New debt ratio.
    function setStrategyDebtRatio(address _strategy, uint256 _debtRatio) external;

    /// @notice Change the minimum amount of debt a strategy can take.
    /// @dev Used to limit the minimum amount of debt a strategy should take. 
    ///      Taking a small credit wouldn't be optimal gas-wise.
    /// @param _strategy Address of the strategy.
    /// @param _minDebtDelta Lower limit of the change of debt.
    function setStrategyMinDebtDelta(address _strategy, uint256 _minDebtDelta) external;

    /// @notice Change the maximum amount of debt a strategy can take at once.
    /// @dev Used to protect large debt repayments or withdraws. Risks are IL, or low liquidity.
    /// @param _strategy Address of the strategy.
    /// @param _maxDebtDelta Upper limit of the change of debt.
    function setStrategyMaxDebtDelta(address _strategy, uint256 _maxDebtDelta) external;

    /// @notice Retires the Multistrategy. End of Life.
    function retire() external;
}