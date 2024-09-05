// SPDX-License-Identifier: GNU AGPLv3

pragma solidity >=0.8.20 <= 0.9.0;

import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import { MultistrategyAdminable } from "src/abstracts/MultistrategyAdminable.sol";
import { IMultistrategyManageable } from "interfaces/infra/multistrategy/IMultistrategyManageable.sol";
import { IStrategyAdapter } from "interfaces/infra/multistrategy/IStrategyAdapter.sol";
import { MStrat } from "src/types/DataTypes.sol";
import { Errors } from "src/infra/libraries/Errors.sol";

abstract contract MultistrategyManageable is IMultistrategyManageable, MultistrategyAdminable {

    /// @dev Maximum amount of different strategies this contract can deposit into
    uint8 constant MAXIMUM_STRATEGIES = 10;

    /// @dev Maximum basis points (10_000 = 100%)
    uint256 constant MAX_BPS = 10_000;

    /// @dev Maximum performance fee that the owner can set is 10%
    uint256 constant MAX_PERFORMANCE_FEE = 1_000;
    
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
    uint256 public slippageLimit;

    /// @inheritdoc IMultistrategyManageable
    uint8 public activeStrategies;

    /*//////////////////////////////////////////////////////////////////////////
                                  PRIVATE STORAGE
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev Strategy parameters mapped by the strategy address
    mapping(address strategyAddress => MStrat.StrategyParams strategyParameters) public strategies;

    /// @dev Order that `_withdraw()` uses to determine which strategy pull the funds from
    //       The first time a zero address is encountered, it stops withdrawing, so it is
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
        address _protocolFeeRecipient
    ) 
        MultistrategyAdminable(_owner, _manager) 
    {
        if(_protocolFeeRecipient == address(0)) {
            revert Errors.ZeroAddress();
        }
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
    function getWithdrawOrder() external view returns (address[] memory) {
        return withdrawOrder;
    }

    /// @inheritdoc IMultistrategyManageable
    function getStrategyParameters(address _strategy) external view returns (MStrat.StrategyParams memory) {
        return strategies[_strategy];
    }

    /*//////////////////////////////////////////////////////////////////////////
                        USER FACING NON-CONSTANT FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @inheritdoc IMultistrategyManageable
    function setProtocolFeeRecipient(address _protocolFeeRecipient) external onlyOwner {
        if(_protocolFeeRecipient == address(0)) {
            revert Errors.ZeroAddress();
        }
        protocolFeeRecipient = _protocolFeeRecipient;
        emit ProtocolFeeRecipientSet(protocolFeeRecipient);
    }

    /// @inheritdoc IMultistrategyManageable
    function setPerformanceFee(uint256 _performanceFee) external onlyOwner {
        if(_performanceFee > MAX_PERFORMANCE_FEE) {
            revert Errors.ExcessiveFee(_performanceFee);
        }
        performanceFee = _performanceFee;
        emit PerformanceFeeSet(performanceFee);
    }

    /// @inheritdoc IMultistrategyManageable
    function setDepositLimit(uint256 _depositLimit) external onlyManager {
        depositLimit = _depositLimit;
        emit DepositLimitSet(depositLimit);
    }

    function setSlippageLimit(uint256 _slippageLimit) external onlyManager {
        slippageLimit = _slippageLimit;
        emit SlippageLimitSet(slippageLimit);
    }

    /// @inheritdoc IMultistrategyManageable
    function setWithdrawOrder(address[] memory _strategies) external onlyManager {
        _validateStrategyOrder(_strategies);
        withdrawOrder = _strategies;
        emit WithdrawOrderSet();
    }

    /// @inheritdoc IMultistrategyManageable
    function addStrategy(
        address _strategy,
        uint256 _debtRatio,
        uint256 _minDebtDelta,
        uint256 _maxDebtDelta
    ) external onlyManager {
        if(activeStrategies >= MAXIMUM_STRATEGIES) {
            revert Errors.MaximumAmountStrategies();
        }
        if(_strategy == address(0) || _strategy == address(this)) {
            revert Errors.InvalidAddress(_strategy);
        }
        if(strategies[_strategy].activation != 0) {
            revert Errors.StrategyAlreadyActive(_strategy);
        }
        if(IERC4626(address(this)).asset() != IStrategyAdapter(_strategy).asset()) {
            revert Errors.AssetMismatch(IERC4626(address(this)).asset(), IStrategyAdapter(_strategy).asset());
        }
        if(debtRatio + _debtRatio > MAX_BPS) {
            revert Errors.DebtRatioAboveMaximum(debtRatio + _debtRatio);
        }
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

        _organizeWithdrawOrder();

        emit StrategyAdded(_strategy);
    }

    /// @inheritdoc IMultistrategyManageable
    function retireStrategy(address _strategy) external onlyManager onlyActiveStrategy(_strategy) {
        debtRatio -= strategies[_strategy].debtRatio;
        strategies[_strategy].debtRatio = 0;

        emit StrategyRetired(_strategy);
    }

    /// @inheritdoc IMultistrategyManageable
    function removeStrategy(address _strategy) external onlyManager onlyActiveStrategy(_strategy) {
        if(strategies[_strategy].debtRatio > 0) {
            revert Errors.StrategyNotRetired();
        }
        if(strategies[_strategy].totalDebt > 0) {
            revert Errors.StrategyWithOutstandingDebt();
        }

        for(uint8 i = 0; i < MAXIMUM_STRATEGIES;) {
            if(withdrawOrder[i] == _strategy) {
                withdrawOrder[i] = address(0);
                strategies[_strategy].activation = 0;
                --activeStrategies;
                _organizeWithdrawOrder();

                emit StrategyRemoved(_strategy);
                return;
            }
            unchecked { ++i; }
        }
    }

    /// @inheritdoc IMultistrategyManageable
    function setStrategyDebtRatio(address _strategy, uint256 _debtRatio) external onlyManager onlyActiveStrategy(_strategy) {
        debtRatio -= strategies[_strategy].debtRatio;
        strategies[_strategy].debtRatio = _debtRatio;
        debtRatio += strategies[_strategy].debtRatio;
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
        if(strategies[_strategy].minDebtDelta > _maxDebtDelta) {
            revert Errors.InvalidDebtDelta();
        }
        strategies[_strategy].maxDebtDelta = _maxDebtDelta;

        emit StrategyMaxDebtDeltaSet(_strategy, _maxDebtDelta);
    }

    /*//////////////////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Validates the order of strategies for withdrawals.
    /// 
    /// This function performs the following actions:
    /// - Ensures the length of the provided strategies array matches the maximum number of strategies.
    /// - Iterates through the provided strategies to validate each one:
    ///   - Checks that non-zero addresses correspond to active strategies.
    ///   - Ensures there are no duplicate strategies in the provided array.
    /// - If an address in the provided array is zero, it checks that all subsequent addresses are also zero.
    /// 
    /// @param _strategies The array of strategy addresses to validate.
    function _validateStrategyOrder(address[] memory _strategies) internal view {
        // Revert if the strategies order length doesn't have the same length as withdrawOrder
        if(_strategies.length != MAXIMUM_STRATEGIES) {
            revert Errors.StrategiesLengthMismatch();
        }
        for(uint8 i = 0; i < MAXIMUM_STRATEGIES; ++i) {
            address strategy = _strategies[i];

            if(strategy != address(0)) {
                if(strategies[strategy].activation == 0) {
                    revert Errors.StrategyNotActive(strategy);
                }
                // Start to check on the next strategy
                for(uint8 j = 0; j < MAXIMUM_STRATEGIES; ++j) {
                    // Check that the strategy isn't duplicate
                    if(i != j && strategy == _strategies[j]) {
                        revert Errors.DuplicateStrategyInArray();
                    }
                }
            } else {
                // Check that the rest of the addresses are address(0)
                for(uint8 j = i + 1; j < MAXIMUM_STRATEGIES; ++j) {
                    if(_strategies[j] != address(0)) {
                        revert Errors.InvalidWithdrawOrder();
                    }
                }
                return;
            }
        }
    }

    /// @notice Organizes the withdraw order by removing gaps and shifting strategies.
    /// 
    /// This function performs the following actions:
    /// - Iterates through the withdraw order array.
    /// - For each strategy, if it encounters an empty slot (address(0)), it shifts subsequent strategies up to fill the gap.
    /// - Ensures that any empty slots are moved to the end of the array.
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