// SPDX-License-Identifier: GNU AGPLv3

pragma solidity >=0.8.20 <= 0.9.0;

import { MultistrategyAdminable } from "src/abstracts/MultistrategyAdminable.sol";
import { IMultistrategyManageable } from "interfaces/infra/multistrategy/IMultistrategyManageable.sol";
import { IStrategyWrapper } from "interfaces/infra/multistrategy/IStrategyWrapper.sol";
import { MStrat } from "src/types/DataTypes.sol";
import { Errors } from "src/infra/libraries/Errors.sol";

contract MultistrategyManageable is IMultistrategyManageable, MultistrategyAdminable {

    /// @dev Maximum amount of different strategies this contract can deposit into
    uint8 constant MAXIMUM_STRATEGIES = 10;

    /// @dev Maximum basis points (10_000 = 100%)
    uint256 constant MAX_BPS = 10_000;

    /// @dev Maximum performance fee that the owner can set is 10%
    uint256 constant MAX_PERFORMANCE_FEE = 1_000;

    /// @inheritdoc IMultistrategyManageable
    address public depositToken;
    
    /// @inheritdoc IMultistrategyManageable
    address public protocolFeeRecipient;

    /// @inheritdoc IMultistrategyManageable
    uint256 public performanceFee;

    /// @inheritdoc IMultistrategyManageable
    uint256 public depositLimit;

    /// @inheritdoc IMultistrategyManageable
    uint256 public debtRatio;

    /// @inheritdoc IMultistrategyManageable
    uint256 public totalDebt;

    /// @inheritdoc IMultistrategyManageable
    uint8 public activeStrategies;

    /*//////////////////////////////////////////////////////////////////////////
                                  PRIVATE STORAGE
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev Strategy parameters mapped by the strategy address
    mapping(address strategyAddress => MStrat.StrategyParams strategyParameters) public strategies;

    /// @dev Order that `_withdraw()` uses to determine which strategy pull the funds from
    //       The first time a zero address is enountered, it stops withdrawing, so it is
    //       possible that there isn't enough to withdraw if the amount of strategies in
    //       `withdrawOrder` is smaller than the amount of active strategies.
    address[] public withdrawOrder;

    /*//////////////////////////////////////////////////////////////////////////
                                     CONSTRUCTOR
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev Initial owner is the deployer of the multistrategy.
    /// @param _owner Address of the initial Multistrategy owner.
    /// @param _manager Address of the initial Multistrategy manager.
    /// @param _protocolFeeRecipient Address that will receive the performance fee.
    constructor(
        address _owner,
        address _manager,
        address _depositToken,
        address _protocolFeeRecipient
    ) 
        MultistrategyAdminable(_owner, _manager) 
    {
        depositToken = _depositToken;
        protocolFeeRecipient = _protocolFeeRecipient;
        withdrawOrder = new address[](MAXIMUM_STRATEGIES);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    MODIFIER
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev Reverts if `_strategy` is not active.
    /// @param _strategy Address of the strategy to check if it is active. 
    modifier onlyActiveStrategy(address _strategy) {
        if(strategies[_strategy].activation == 0) {
            revert Errors.StrategyNotActive(_strategy);
        }
        _;
    }

    /*//////////////////////////////////////////////////////////////////////////
                        USER FACING CONSTANT FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @inheritdoc IMultistrategyManageable
    function getWithdrawOrder() external view returns(address[] memory) {
        return withdrawOrder;
    }

    /// @inheritdoc IMultistrategyManageable
    function getStrategyParameters(address _strategy) external view returns(MStrat.StrategyParams memory) {
        return strategies[_strategy];
    }

    /*//////////////////////////////////////////////////////////////////////////
                        USER FACING NON-CONSTANT FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @inheritdoc IMultistrategyManageable
    function setProtocolFeeRecipient(address _protocolFeeRecipient) external onlyOwner {
        protocolFeeRecipient = _protocolFeeRecipient;
        emit ProtocolFeeRecipientSet(_protocolFeeRecipient);
    }

    /// @inheritdoc IMultistrategyManageable
    function setPerformanceFee(uint256 _performanceFee) external onlyOwner {
        if(_performanceFee > MAX_PERFORMANCE_FEE) {
            revert Errors.ExcessiveFee({ fee: _performanceFee });
        }
        performanceFee = _performanceFee;
        emit PerformanceFeeSet(_performanceFee);
    }

    /// @inheritdoc IMultistrategyManageable
    function setDepositLimit(uint256 _depositLimit) external onlyManager {
        depositLimit = _depositLimit;
        emit DepositLimitSet(_depositLimit);
    }

    /// @inheritdoc IMultistrategyManageable
    function setWithdrawalOrder(address[] memory _strategies) external onlyManager {
        _validateStrategyOrder(_strategies);
        withdrawOrder = _strategies;
    }

    /// @inheritdoc IMultistrategyManageable
    function addStrategy(
        address _strategy,
        uint256 _debtRatio,
        uint256 _minDebtDelta,
        uint256 _maxDebtDelta
    ) external onlyManager {
        // Assert limit of maximum strategies is respected.
        if(activeStrategies >= MAXIMUM_STRATEGIES) {
            revert Errors.MaximumAmountStrategies();
        }
        // Assert is not Zero Address or the address of the multistrategy.
        if(_strategy == address(0) || _strategy == address(this)) {
            revert Errors.InvalidAddress({ addr: _strategy });
        }
        // Assert we're not adding an already active strategy.
        if(strategies[_strategy].activation != 0) {
            revert Errors.StrategyAlreadyActive({ strategy: _strategy });
        }
        // Assert strategy's `depositToken` matches this multistrategy's `depositToken`.
        if(depositToken != IStrategyWrapper(_strategy).depositToken()) {
            revert Errors.DepositTokenMissmatch({
                multDepositToken: depositToken,
                stratDepositToken: IStrategyWrapper(_strategy).depositToken()
            });
        }
        // Assert new `debtRatio` will be below or equal 100%.
        if(debtRatio + _debtRatio > MAX_BPS) {
            revert Errors.DebtRatioAboveMaximum({ debtRatio: debtRatio + _debtRatio});
        }
        // Assert `minDebtDelta` is lower or equal than `maxDebtDelta`.
        if(_minDebtDelta > _maxDebtDelta) {
            revert Errors.InvalidDebtDelta();
        }

        strategies[_strategy] = MStrat.StrategyParams({
            activation: block.timestamp,
            debtRatio: _debtRatio,
            lastReport: block.timestamp,
            minDebtDelta: _minDebtDelta,
            maxDebtDelta: _maxDebtDelta,
            totalDebt: 0,
            totalGain: 0,
            totalLoss: 0
        });

        debtRatio += _debtRatio;
        withdrawOrder[MAXIMUM_STRATEGIES - 1] = _strategy;
        ++activeStrategies;

        // Organize the withdraw order
        _organizeWithdrawOrder();

        emit StrategyAdded(_strategy);
    }

    /// @inheritdoc IMultistrategyManageable
    function retireStrategy(address _strategy) external onlyManager onlyActiveStrategy(_strategy) {
        debtRatio -= strategies[_strategy].debtRatio;
        strategies[_strategy].debtRatio = 0;

        emit StrategyRevoked(_strategy);
    }

    /// @inheritdoc IMultistrategyManageable
    function removeStrategy(address _strategy) external onlyManager {
        for(uint8 i = 0; i <= MAXIMUM_STRATEGIES;) {
            if(withdrawOrder[i] == _strategy) {
                // Remove the strategy from the withdraw order and organize it.
                withdrawOrder[i] = address(0);
                _organizeWithdrawOrder();

                emit StrategyRemoved(_strategy);
                return;
            }
            unchecked { ++i; }
        }
        // If we reach this point, _strategy wasn't on the withdraw order array.
        revert Errors.StrategyNotFound();
    }

    /// @inheritdoc IMultistrategyManageable
    function setStrategyDebtRatio(address _strategy, uint256 _debtRatio) external onlyManager onlyActiveStrategy(_strategy) {
        // Reduce the debtRatio of the multistrategy by the "old" debtRatio of the strategy.
        debtRatio -= strategies[_strategy].debtRatio;
        // Assign the new debtRatio.
        strategies[_strategy].debtRatio = _debtRatio;
        // Increase the debtRatio of the multistrategy with the "new" debtRatio of the strategy.
        debtRatio += strategies[_strategy].debtRatio;

        // Assert that debtRatio <= 100%
        if(debtRatio > MAX_BPS) {
            revert Errors.DebtRatioAboveMaximum(debtRatio);
        }

        emit StrategyDebtRatioSet(_strategy, _debtRatio );
    }

    /// @inheritdoc IMultistrategyManageable
    function setStrategyMinDebtDelta(address _strategy, uint256 _minDebtDelta) external 
        onlyManager  
        onlyActiveStrategy(_strategy) 
    {
        // Check that maxDebtDelta isn't lower than minDebtDelta
        if(strategies[_strategy].maxDebtDelta < _minDebtDelta) {
            revert Errors.InvalidDebtDelta();
        }

        strategies[_strategy].minDebtDelta = _minDebtDelta;

        emit StrategyMinDebtDeltaSet(_strategy, _minDebtDelta);
    }

    /// @inheritdoc IMultistrategyManageable
    function setStrategyMaxDebtDelta(address _strategy, uint256 _maxDebtDelta) external 
        onlyManager 
        onlyActiveStrategy(_strategy) 
    {
        // Check that minDebtDelta isn't higher than maxDebtDelta
        if(strategies[_strategy].minDebtDelta > _maxDebtDelta) {
            revert Errors.InvalidDebtDelta();
        }

        strategies[_strategy].maxDebtDelta = _maxDebtDelta;

        emit StrategyMaxDebtDeltaSet(_strategy, _maxDebtDelta);
    }

    /*//////////////////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Validates `_strategies` input so all strategies are active, exist in the withdrawOrder and
    /// the input doesn't include any duplicate addresses.
    /// @param _strategies Array of active strategies
    function _validateStrategyOrder(address[] memory _strategies) internal view {
        // Revert if the strategies order length doesn't have the same length as withdrawOrder
        if(_strategies.length != MAXIMUM_STRATEGIES) {
            revert Errors.StrategiesLengthMissMatch();
        }
        for(uint8 i = 0; i < MAXIMUM_STRATEGIES;) {
            //Strategy needs to be active
            if(strategies[_strategies[i]].activation == 0) {
                revert Errors.StrategyNotActive(_strategies[i]);
            }

            bool strategyExists = false;
            for(uint8 j = 0; j < MAXIMUM_STRATEGIES;) {
                if(_strategies[j] == address(0)) {
                    strategyExists = true;
                }
                // Check that the strategy exists 
                if(_strategies[i] == withdrawOrder[j]) {
                    strategyExists = true;
                }
                // This prevents from checking already checked duplicates.
                if(j <= i) {
                    continue;
                }
                // No duplicates
                if(_strategies[i] != _strategies[j]) {
                    revert Errors.DuplicateStrategyInArray();
                }
                unchecked { ++j; }
            }
            // If a strategy in _strategies doesn't exist in withdrawOrder. Throw an error.
            if(!strategyExists) {
                revert Errors.StrategyNotFound();
            }
            unchecked { ++i; }
        }
    }

    /// @notice Organizes `withdrawOrder` array so there is not a Zero Address between two active strategies.
    /// This is needed because some functions end if they find a Zero Address in the array, as it is supposed that
    /// All the addresses after Zero Address will be Zero Address too.
    function _organizeWithdrawOrder() internal {
        uint8 position = 0;
        for(uint8 i = 0; i < MAXIMUM_STRATEGIES;) {
            address strategy = withdrawOrder[i];
            if(strategy == address(0)) {
                ++position;
            } else if (position > 0) {
                withdrawOrder[i - position] = strategy;
                withdrawOrder[i] = address(0);
            }
            unchecked { ++i; }
        }
    }
}