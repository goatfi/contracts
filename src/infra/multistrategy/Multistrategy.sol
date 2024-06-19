// SPDX-License-Identifier: GNU AGPLv3

pragma solidity >=0.8.20 <= 0.9.0;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { IERC20, SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { MultistrategyManageable } from "src/abstracts/MultistrategyManageable.sol";
import { IMultistrategy } from "interfaces/infra/multistrategy/IMultistrategy.sol";
import { IStrategyAdapter } from "interfaces/infra/multistrategy/IStrategyAdapter.sol";
import { Errors } from "src/infra/libraries/Errors.sol";

contract Multistrategy is IMultistrategy, MultistrategyManageable, ERC20 {
    using SafeERC20 for IERC20;
    
    /// @dev Used for locked profit calculations. Must be 10 ** depositToken decimals.
    uint256 immutable DEGRADATION_COEFFICIENT;
    /// @dev How much time it takes for the profit of a strategy to be unlocked.
    uint256 constant PROFIT_UNLOCK_TIME = 12 hours;

    /// @inheritdoc IMultistrategy
    uint256 public lastReport;
    
    /// @inheritdoc IMultistrategy
    uint256 public lockedProfit;

    /// @inheritdoc IMultistrategy
    uint256 public lockedProfitDegradation;

    /*//////////////////////////////////////////////////////////////////////////
                                     CONSTRUCTOR
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev Transfers ownership to the deployer of this contract
    /// @param _depositToken Address of the token used in this Multistrategy
    /// @param _manager Address of the initial Multistrategy manager
    /// @param _protocolFeeRecipient Address that will receive the performance fees
    /// @param _name Name of this Multistrategy receipt token
    /// @param _symbol Symbol of this Multistrategy receipt token
    constructor(
        address _depositToken,
        address _manager,
        address _protocolFeeRecipient,
        string memory _name, 
        string memory _symbol
    ) 
        MultistrategyManageable(msg.sender, _manager, _depositToken, _protocolFeeRecipient) 
        ERC20(_name, _symbol) 
    {   
        // Set performance fee to 4% of yield generated
        performanceFee = 400;
        // Set the initial lastReport to the timestamp when creating the multistrategy
        lastReport = block.timestamp;
        // Set the degradation coefficient to 1 whole unit of deposit token.
        DEGRADATION_COEFFICIENT = 10 ** IERC20Metadata(_depositToken).decimals();
        // How much profit is unlocked each second. This sets the unlock time to 12h
        lockedProfitDegradation = DEGRADATION_COEFFICIENT / PROFIT_UNLOCK_TIME;
    }

    /*//////////////////////////////////////////////////////////////////////////
                        USER FACING CONSTANT FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @inheritdoc IMultistrategy
    function totalAssets() external view returns(uint256) {
        return _totalAssets();
    }

    /// @inheritdoc IMultistrategy
    function pricePerShare() external view returns(uint256) {
        return _shareValue(1 ether);
    }

    /// @inheritdoc IMultistrategy
    function creditAvailable(address _strategy) external view returns(uint256) {
        return _creditAvailable(_strategy);
    }

    /// @inheritdoc IMultistrategy
    function debtExcess(address _strategy) external view returns(uint256) {
        return _debtExcess(_strategy);
    }

    function strategyTotalDebt(address _strategy) external view returns(uint256) {
        return strategies[_strategy].totalDebt;
    }

    /*//////////////////////////////////////////////////////////////////////////
                        USER FACING NON-CONSTANT FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @inheritdoc IMultistrategy
    function deposit(uint256 _amount, address _recipient) external {
        _deposit(_amount, _recipient);
    }

    /// @inheritdoc IMultistrategy
    function deposit(uint256 _amount) external {
        _deposit(_amount, msg.sender);
    }

    /// @inheritdoc IMultistrategy
    function withdraw(uint256 _amount) external {
        _withdraw(_amount);
    }

    /// @inheritdoc IMultistrategy
    function withdrawAll() external {
        uint256 userBalance = balanceOf(msg.sender);
        _withdraw(userBalance);
    }

    /// @inheritdoc IMultistrategy
    function requestCredit() external {
        _requestCredit();
    }

    /// @inheritdoc IMultistrategy
    function strategyReport(uint256 _debtRepayment, uint256 _profit, uint256 _loss) external {
        _report(_debtRepayment, _profit, _loss);
    }

    /// @inheritdoc IMultistrategy
    function rescueToken(address _token, address _recipient) external {
        _rescueToken(_token, _recipient);
    }

    /*//////////////////////////////////////////////////////////////////////////
                            INTERNAL CONSTANT FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev Returns the assets this Multistrategy holds.
    /// Note that these are the *expected* assets, as it is calculated via the totalDebt
    /// this Multistrategy has issued to the strategies.
    function _totalAssets() internal view returns(uint256) {
        uint256 idleAssets = IERC20(depositToken).balanceOf(address(this));
        return idleAssets + totalDebt;
    }

    /// @dev Determines the value of "shares" in depositToken amount
    /// @param _shares Amount of shares
    function _shareValue(uint256 _shares) internal view returns(uint256) {
        if(totalSupply() == 0){
            return _shares;
        }

        uint256 value = _shares * _freeFunds() / totalSupply();
        return value;
    }

    /// @dev Determines how many shares "amount" of depositToken would receieve
    /// @param _amount Amount of depositToken
    function _sharesForAmount(uint256 _amount) internal view returns(uint256) {
        uint256 freeFunds = _freeFunds();

        if(freeFunds > 0){
            uint256 shares = _amount * totalSupply() / freeFunds;
            return shares;
        }

        return 0;
    }

    /// @dev This will check the strategy's debt limit and the tokens available in the Multistrategy 
    ///      in order to calculate the max amount of tokens a strategy can borrow.
    /// @param _strategy Address of the strategy we want to know the credit available for.
    function _creditAvailable(address _strategy) internal view returns(uint256) {
        uint256 mult_totalAssets = _totalAssets();
        uint256 mult_debtLimit = debtRatio * mult_totalAssets / MAX_BPS;
        uint256 mult_totalDebt = totalDebt;

        uint256 strat_debtLimit = strategies[_strategy].debtRatio * mult_totalAssets / MAX_BPS;
        uint256 strat_totalDebt = strategies[_strategy].totalDebt;
        uint256 strat_minDebtDelta = strategies[_strategy].minDebtDelta;
        uint256 strat_maxDebtDelta = strategies[_strategy].maxDebtDelta;

        // If a strategy has borrowed more than what is permited
        // or
        // the multistrategy has more debt than its limit
        // do *NOT* offer any new credit
        if(strat_totalDebt >= strat_debtLimit || mult_totalDebt >= mult_debtLimit){
            return 0;
        }

        // Initially offer the max amount the strategy could ask for
        // which is its debt limit minus any outstanding debt it may have
        uint256 credit = strat_debtLimit - strat_totalDebt;

        // The maximum amount the multistrategy can offer as credit is the difference
        // between the current debt and the debt limit.
        uint256 maxAvailableCredit = mult_debtLimit - mult_totalDebt;

        // We take the smaller amount between the two
        credit = Math.min(credit, maxAvailableCredit);

        // Bound to the minimum and maximum borrow limits
        if(credit < strat_minDebtDelta) {
            // If the available credit is below the minimum, return 0.
            return 0;
        } else {
            // Make sure we don't credit more than the maximum.
            return Math.min(credit, strat_maxDebtDelta);
        }
    }

    /// @dev If a strategy doesn't have an excess of debt, it will return 0.
    /// @param _strategy Address of the strategy we want to know if it has any debt excess.
    function _debtExcess(address _strategy) internal view returns(uint256) {
        // If the debtRatio is 0, means the multistrategy doesn't want to offer any credits
        // which means, all debt is excess debt.
        if(debtRatio == 0) {
            return strategies[_strategy].totalDebt;
        }

        uint256 strat_debtLimit = strategies[_strategy].debtRatio * _totalAssets() / MAX_BPS;
        uint256 strat_totalDebt = strategies[_strategy].totalDebt;

        // If the total debt of a strategy is below its debt limit, there is no excess debt.
        if(strat_totalDebt <= strat_debtLimit) {
            return 0;
        } else {
            // Else, the excess debt is the difference between the total debt and debt limit.
            return strat_totalDebt - strat_debtLimit;
        }
    }
    
    /// @dev Returns the assets the multistrategy holds minus the profit that is locked
    ///      Used to calculate the share price, as the profit that is locked cannot be
    ///      reflected in the share price.
    function _freeFunds() internal view returns(uint256) {
        return _totalAssets() - _calculateLockedProfit();
    }

    /// @dev Returns the amount of profit that is still locked.
    function _calculateLockedProfit() internal view returns(uint256) {
        uint256 lockedFundsRatio = (block.timestamp - lastReport) * lockedProfitDegradation;

        if(lockedFundsRatio < DEGRADATION_COEFFICIENT) {
            return lockedProfit - Math.mulDiv(lockedFundsRatio, lockedProfit, DEGRADATION_COEFFICIENT);
        }
        return 0;
    }

    /*//////////////////////////////////////////////////////////////////////////
                            INTERNAL NON-CONSTANT FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/


    function _deposit(uint256 _amount, address _recipient) internal whenNotPaused {
        if(_recipient == address(0) || _recipient == address(this)) {
            revert Errors.InvalidAddress({ addr: _recipient });
        }
        //Assert something gets deposited
        if(_amount == 0) {
            revert Errors.ZeroAmount({ amount: _amount });
        }

        //Assert deposit limit is respected
        if(_amount + _totalAssets() > depositLimit) {
            revert Errors.DepositLimit();
        }

        //Mint shares
        _issueSharesForAmount(_amount, _recipient);

        //Get funds from depositor
        IERC20(depositToken).safeTransferFrom(msg.sender, address(this), _amount);

        emit Deposit(_amount, _recipient);
    }

    function _withdraw(uint256 _amount) internal whenNotPaused {
        //Assert withdrawer has enough balance
        if(balanceOf(msg.sender) > _amount) {
            revert Errors.InsufficientBalance({ 
                currentBalance: balanceOf(msg.sender), 
                amount: _amount 
            });
        }

        //Assert something is being withdrawn
        if(_amount == 0) {
            revert Errors.ZeroAmount({ amount: _amount });
        }

        // Get depositToken value from the amount of shares.
        // This is the amount that the user wants to receive.
        uint256 balanceToWithdraw = _shareValue(_amount);

        //If the amount the user wants to withdraw is higher than the amount of
        //idle assets on the multistrategy, withdraw from strategies
        if(balanceToWithdraw > IERC20(depositToken).balanceOf(address(this))) {
            for(uint8 i = 0; i <= withdrawOrder.length;){
                address strategy = withdrawOrder[i];

                // We reached the end of the withdraw queue
                if(strategy == address(0)){
                    break;
                }

                uint256 balanceBeforeWithdraw = IERC20(depositToken).balanceOf(address(this));

                // The multistrategy now holds enough to cover the withdraw, 
                // so we're done withdrawing from strategies.
                if(balanceToWithdraw <= balanceBeforeWithdraw){
                    break;
                }

                // At this point we don't have enough to cover the withdraw, so
                // we need to know the amount we need to withdraw.
                uint256 amountNeeded = balanceToWithdraw - balanceBeforeWithdraw;

                // We can't withdraw from a strategy more than what it has.
                amountNeeded = Math.min(amountNeeded, strategies[strategy].totalDebt);

                // Check that the strategy actually has something to withdraw
                if(amountNeeded == 0) {
                    continue;
                }

                // We withdraw from the strategy
                IStrategyAdapter(strategy).withdraw(amountNeeded);
                uint256 withdrawn = IERC20(depositToken).balanceOf(address(this)) - balanceBeforeWithdraw;

                // Reduce the strategy's and multistretegy's totalDebt
                strategies[strategy].totalDebt -= withdrawn;
                totalDebt -= withdrawn;

                unchecked { ++i; }
            }

            uint256 currentBalance = IERC20(depositToken).balanceOf(address(this));

            // At this point we have withdrawn everything possible from the withdrawal queue
            // so we need to make sure that the amount the caller wants to withdraw is lower or equal than the available balance
            // In the case it isn't enough, we let the caller withdraw all the balance and we adjust the amount of shares we'll burn
            // to the balance that is being withdrawn.
            if(balanceToWithdraw > currentBalance) {
                balanceToWithdraw = currentBalance;
                _amount = _sharesForAmount(balanceToWithdraw);
            }
        }

        //Burn the shares
        _burn(msg.sender, _amount);
        //Send the tokens to the caller
        IERC20(depositToken).safeTransfer(msg.sender, balanceToWithdraw);

        emit Withdraw(_amount);
    }

    function _requestCredit() internal whenNotPaused onlyActiveStrategy(msg.sender) {
        uint256 credit = _creditAvailable(msg.sender);

        // Check that the strategy has some credit available
        if(credit > 0) {

            // Update the total debt of the strategy and multistrategy
            strategies[msg.sender].totalDebt += credit;
            totalDebt += credit;

            // Transfer the credit to the strategy
            IERC20(depositToken).safeTransfer(msg.sender, credit);

            emit CreditRequested(msg.sender, credit);
        }
    }

    function _report(uint256 _debtRepayment, uint256 _gain, uint256 _loss) 
        internal 
        whenNotPaused 
        onlyActiveStrategy(msg.sender) 
    {
        // Check that the strategy isn't reporting a gain and a loss at the same time.
        if(_gain > 0 && _loss > 0) {
            revert Errors.GainLossMissmatch();
        }
        // Check that the strategy actually has the tokens to transfer the profits and repay the debt.
        if(IERC20(depositToken).balanceOf(msg.sender) < _debtRepayment + _gain) {
            revert Errors.InsufficientBalance({ 
                currentBalance: IERC20(depositToken).balanceOf(msg.sender),
                amount: _debtRepayment + _gain
            });
        }
        // If the strategy is reporting a loss, realize it.
        if(_loss > 0) {
            _reportLoss(msg.sender, _loss);
        }

        uint256 profit = 0;

        if(_gain > 0) {
            uint256 pFee = Math.mulDiv(_gain, performanceFee, MAX_BPS);

            // Transfer the performance fee to the fee recipient
            if(pFee > 0) {
                IERC20(depositToken).safeTransferFrom(msg.sender, protocolFeeRecipient, pFee);
            }

            // Transfer the profit from the strategy to this multistrategy.
            profit = _gain - pFee;
            IERC20(depositToken).safeTransferFrom(msg.sender, address(this), profit);
        } 

        uint256 debt = _debtExcess(msg.sender);
        uint256 debtToRepay = Math.min(_debtRepayment, debt);

        // If the strategy has made any funds available for repayment and the strategy has more debt
        // than it should, the strategy will repay the debt with the funds that has made available
        // or up to the amount that would remove the excess of debt.
        if(debtToRepay > 0) {
            strategies[msg.sender].totalDebt -= debtToRepay;
            totalDebt -= debtToRepay;

            IERC20(depositToken).safeTransferFrom(msg.sender, address(this), debtToRepay);
        }

        // Calculate the new locked profit. Profit can be 0.
        uint256 newLockedProfit = _calculateLockedProfit() + profit;
        
        // If the loss is smaller than the locked profit, we reduce it by the loss the strategy has realised.
        // Loss can be 0.
        if(newLockedProfit > _loss) {
            lockedProfit = newLockedProfit - _loss;
        } else {
            // If the loss is bigger or equal to the locked profit. There is no profit to be locked.
            lockedProfit = 0;
        }

        // Update the reporting
        strategies[msg.sender].lastReport = block.timestamp;
        lastReport = block.timestamp;

        emit StrategyReported(msg.sender, debtToRepay, profit, _loss);
    }

    function _reportLoss(address _strategy, uint256 _loss) internal {
        uint256 strat_totalDebt = strategies[_strategy].totalDebt;
        // Check that the strategy isn't reporting an incorrect loss, as it can only lose up to
        // the total debt it had.
        if(_loss > strat_totalDebt) {
            revert Errors.InvalidStrategyLoss();
        }

        strategies[_strategy].totalLoss += _loss;
        strategies[_strategy].totalDebt -= _loss;
        totalDebt -= _loss;
    }

    function _issueSharesForAmount(uint256 _amount, address _recipient) internal {
        uint256 shares = 0;
        uint256 totalSupply = totalSupply();

        if(totalSupply > 0) {
            shares = _amount * totalSupply / _freeFunds();
        } else {
            shares = _amount;
        }

        _mint(_recipient, _amount);
    }

    function _rescueToken(address _token, address _recipient) internal onlyGuardian {
        // Check that we aren't stealing from the multistrategy.
        if(_token == depositToken) {
            revert Errors.InvalidAddress(_token);
        }

        uint256 amount = IERC20(_token).balanceOf(address(this));
        IERC20(_token).safeTransfer(_recipient, amount);
    }
}