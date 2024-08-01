// SPDX-License-Identifier: GNU AGPLv3

pragma solidity >=0.8.20 <= 0.9.0;

import { 
    IERC20,
    IERC4626,
    ERC20,
    ERC4626
} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { MultistrategyManageable } from "src/abstracts/MultistrategyManageable.sol";
import { IMultistrategy } from "interfaces/infra/multistrategy/IMultistrategy.sol";
import { IStrategyAdapter } from "interfaces/infra/multistrategy/IStrategyAdapter.sol";
import { Errors } from "src/infra/libraries/Errors.sol";

contract Multistrategy is IMultistrategy, MultistrategyManageable, ERC4626 {
    using SafeERC20 for IERC20;
    
    /// @dev Used for locked profit calculations. Must be 10 ** asset decimals.
    uint256 immutable DEGRADATION_COEFFICIENT;
    /// @dev How much time it takes for the profit of a strategy to be unlocked.
    uint256 constant PROFIT_UNLOCK_TIME = 12 hours;

    /// @inheritdoc IMultistrategy
    uint256 public lastReport;
    
    /// @inheritdoc IMultistrategy
    uint256 public lockedProfit;

    /// @inheritdoc IMultistrategy
    uint256 public immutable lockedProfitDegradation;

    /*//////////////////////////////////////////////////////////////////////////
                                     CONSTRUCTOR
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev Transfers ownership to the deployer of this contract
    /// @param _asset Address of the token used in this Multistrategy
    /// @param _manager Address of the initial Multistrategy manager
    /// @param _protocolFeeRecipient Address that will receive the performance fees
    /// @param _name Name of this Multistrategy receipt token
    /// @param _symbol Symbol of this Multistrategy receipt token
    constructor(
        address _asset,
        address _manager,
        address _protocolFeeRecipient,
        string memory _name, 
        string memory _symbol
    ) 
        MultistrategyManageable(msg.sender, _manager, _protocolFeeRecipient)
        ERC4626(IERC20(_asset))
        ERC20(_name, _symbol) 
    {   
        // Set performance fee to 4% of yield generated
        performanceFee = 400;
        // Set the initial lastReport to the timestamp when creating the multistrategy
        lastReport = block.timestamp;
        // Set the degradation coefficient to 1 whole unit of asset.
        DEGRADATION_COEFFICIENT = 10 ** IERC20Metadata(_asset).decimals();
        // How much profit is unlocked each second. This sets the unlock time to 12h
        lockedProfitDegradation = DEGRADATION_COEFFICIENT / PROFIT_UNLOCK_TIME;
    }

    /*//////////////////////////////////////////////////////////////////////////
                        USER FACING CONSTANT FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @inheritdoc IERC4626
    function totalAssets() public view override returns(uint256) {
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

    /// @inheritdoc IMultistrategy
    function strategyTotalDebt(address _strategy) external view returns(uint256) {
        return strategies[_strategy].totalDebt;
    }

    /*//////////////////////////////////////////////////////////////////////////
                        USER FACING NON-CONSTANT FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @inheritdoc IERC4626
    function deposit(uint256 _assets, address _receiver) public override whenNotPaused returns (uint256) {
        uint256 maxAssets = maxDeposit(_receiver);
        if (_assets > maxAssets) {
            revert ERC4626ExceededMaxDeposit(_receiver, _assets, maxAssets);
        }

        uint256 shares = previewDeposit(_assets);
        _deposit(_msgSender(), _receiver, _assets, shares);

        return shares;
    }

    /// @inheritdoc IERC4626
    function mint(uint256 shares, address receiver) public override whenNotPaused returns (uint256) {
        uint256 maxShares = maxMint(receiver);
        if (shares > maxShares) {
            revert ERC4626ExceededMaxMint(receiver, shares, maxShares);
        }

        uint256 assets = previewMint(shares);
        _deposit(_msgSender(), receiver, assets, shares);

        return assets;
    }

    /// @inheritdoc IERC4626
    function withdraw(uint256 assets, address receiver, address owner) public override whenNotPaused returns (uint256) {
        uint256 maxAssets = maxWithdraw(owner);
        if (assets > maxAssets) {
            revert ERC4626ExceededMaxWithdraw(owner, assets, maxAssets);
        }

        uint256 shares = previewWithdraw(assets);
        _withdraw(_msgSender(), receiver, owner, assets, shares);

        return shares;
    }

    /// @inheritdoc IERC4626
    function redeem(uint256 shares, address receiver, address owner) public override whenNotPaused returns (uint256) {
        uint256 maxShares = maxRedeem(owner);
        if (shares > maxShares) {
            revert ERC4626ExceededMaxRedeem(owner, shares, maxShares);
        }

        uint256 assets = previewRedeem(shares);
        _withdraw(_msgSender(), receiver, owner, assets, shares);

        return assets;
    }

    /// @inheritdoc IMultistrategy
    function requestCredit() external whenNotPaused onlyActiveStrategy(msg.sender) returns (uint256) {
        return _requestCredit();
    }

    /// @inheritdoc IMultistrategy
    function strategyReport(uint256 _debtRepayment, uint256 _profit, uint256 _loss) 
        external 
        whenNotPaused 
        onlyActiveStrategy(msg.sender)
    {
        _report(_debtRepayment, _profit, _loss);
    }

    /// @inheritdoc IMultistrategy
    function rescueToken(address _token, address _recipient) external onlyGuardian {
        _rescueToken(_token, _recipient);
    }

    /*//////////////////////////////////////////////////////////////////////////
                            INTERNAL CONSTANT FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Internal view function to calculate the total assets held by the contract.
    /// 
    /// This function performs the following actions:
    /// - Retrieves the balance of idle assets (tokens) held by the contract.
    /// - Adds the total debt to the idle assets to determine the total assets.
    /// 
    /// @return The total assets held by the contract.
    function _totalAssets() internal view returns(uint256) {
        uint256 idleAssets = IERC20(asset()).balanceOf(address(this));
        return idleAssets + totalDebt;
    }

    /// @notice Internal view function to calculate the value of a given number of shares.
    /// 
    /// This function performs the following actions:
    /// - If the total supply of shares is zero, returns the number of shares as the value.
    /// - Otherwise, calculates the value of the shares as a proportion of the free funds to the total supply.
    /// 
    /// @param _shares The number of shares to calculate the value for.
    /// @return The value corresponding to the given number of shares.
    function _shareValue(uint256 _shares) internal view returns(uint256) {
        if(totalSupply() == 0){
            return _shares;
        }

        uint256 value = Math.mulDiv(_shares, _freeFunds(), totalSupply());
        return value;
    }

    /// @notice Internal view function to calculate the number of shares corresponding to a given amount.
    /// 
    /// This function performs the following actions:
    /// - Retrieves the free funds available in the contract.
    /// - If there are free funds, calculates the shares as a proportion of the total supply to the free funds.
    /// - If there are no free funds, returns zero.
    /// 
    /// @param _amount The amount for which to calculate the corresponding shares.
    /// @return The number of shares corresponding to the given amount.
    function _sharesForAmount(uint256 _amount) internal view returns(uint256) {
        uint256 freeFunds = _freeFunds();

        if(freeFunds > 0){
            uint256 shares = Math.mulDiv(_amount, totalSupply(), freeFunds);
            return shares;
        }

        return 0;
    }

    /// @notice Internal view function to calculate the available credit for a strategy.
    /// 
    /// This function performs the following actions:
    /// - Determines the total assets and debt limits for both the multi-strategy and the specific strategy.
    /// - Checks if the strategy or the multi-strategy has exceeded their respective debt limits, in which case no new credit is offered.
    /// - Calculates the potential credit as the difference between the strategy's debt limit and its current debt.
    /// - Limits the potential credit by the maximum available credit of the multi-strategy.
    /// - Ensures the potential credit is within the strategy's minimum and maximum debt delta bounds.
    /// - Returns zero if the available credit is below the strategy's minimum debt delta.
    /// - Returns the available credit, ensuring it does not exceed the strategy's maximum debt delta.
    /// 
    /// @param _strategy The address of the strategy for which to determine the available credit.
    /// @return The amount of credit available for the given strategy.
    function _creditAvailable(address _strategy) internal view returns(uint256) {
        uint256 mult_totalAssets = _totalAssets();
        uint256 mult_debtLimit = Math.mulDiv(debtRatio, mult_totalAssets, MAX_BPS);
        uint256 mult_totalDebt = totalDebt;

        uint256 strat_debtLimit = Math.mulDiv(strategies[_strategy].debtRatio, mult_totalAssets, MAX_BPS);
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

    /// @notice Internal view function to calculate the excess debt of a strategy.
    /// 
    /// This function performs the following actions:
    /// - If the overall debt ratio is zero, it returns the total debt of the strategy as excess debt.
    /// - Calculates the strategy's debt limit based on its debt ratio and the total assets.
    /// - If the strategy's total debt is less than or equal to its debt limit, it returns zero indicating no excess debt.
    /// - If the strategy's total debt exceeds its debt limit, it returns the difference as the excess debt.
    /// 
    /// @param _strategy The address of the strategy for which to determine the debt excess.
    /// @return The amount of excess debt for the given strategy.
    function _debtExcess(address _strategy) internal view returns(uint256) {
        // If the debtRatio is 0, means the multistrategy doesn't want to offer any credits
        // which means, all debt is excess debt.
        if(debtRatio == 0) {
            return strategies[_strategy].totalDebt;
        }

        uint256 strat_debtLimit = Math.mulDiv(strategies[_strategy].debtRatio, _totalAssets(), MAX_BPS);
        uint256 strat_totalDebt = strategies[_strategy].totalDebt;

        // If the total debt of a strategy is below its debt limit, there is no excess debt.
        if(strat_totalDebt <= strat_debtLimit) {
            return 0;
        } else {
            // Else, the excess debt is the difference between the total debt and debt limit.
            return strat_totalDebt - strat_debtLimit;
        }
    }
    
    /// @notice Internal view function to calculate the free funds available in the contract.
    /// 
    /// This function performs the following actions:
    /// - Retrieves the total assets held by the contract.
    /// - Subtracts the current locked profit from the total assets to determine the free funds.
    /// 
    /// @return The amount of free funds available.
    function _freeFunds() internal view returns(uint256) {
        return _totalAssets() - _calculateLockedProfit();
    }

    /// @notice Internal view function to calculate the current locked profit.
    /// 
    /// This function performs the following actions:
    /// - Calculates the locked funds ratio based on the time elapsed since the last report and the locked profit degradation rate.
    /// - If the locked funds ratio is less than the degradation coefficient, it computes the remaining locked profit by reducing it proportionally.
    /// - If the locked funds ratio is greater than or equal to the degradation coefficient, it returns zero indicating no locked profit remains.
    /// 
    /// @return The calculated current locked profit.
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

    /// @notice Internal function to handle deposits into the contract.
    /// 
    /// This function performs the following actions:
    /// - Validates that the recipient address is not the zero address or the contract address itself.
    /// - Checks that the deposit amount is greater than zero.
    /// - Ensures the deposit does not exceed the deposit limit.
    /// - Mints shares equivalent to the deposit amount for the recipient.
    /// - Transfers the deposit amount from the depositor to the contract.
    ///
    /// Requirements:
    /// - The contract must not be paused.
    /// - The recipient address must not be zero or the contract address.
    /// - The deposit amount must be greater than zero.
    /// - The deposit amount must not exceed the deposit limit.
    ///
    /// Emits a `Deposit` event.
    /// 
    /// @param _amount The amount to be deposited.
    /// @param _recipient The address of the recipient to receive shares for the deposit.
    function _deposit(uint256 _amount, address _recipient) internal {
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
        IERC20(asset()).safeTransferFrom(msg.sender, address(this), _amount);

        emit Deposit(_amount, _recipient);
    }

    /// @notice Internal function to handle withdrawals from the contract.
    /// 
    /// This function performs the following actions:
    /// - Ensures the withdrawer has sufficient balance to withdraw the specified amount.
    /// - Validates that a non-zero amount is being withdrawn.
    /// - Calculates the base asset value from the amount of shares.
    /// - Checks if the withdrawal amount exceeds the idle assets available in the contract and withdraws from strategies if needed.
    /// - Iterates through the withdrawal queue to cover the withdrawal amount from different strategies.
    /// - Burns the shares equivalent to the withdrawal amount.
    /// - Transfers the withdrawal amount to the caller.
    ///
    /// Requirements:
    /// - The contract must not be paused.
    /// - The withdrawer must have enough balance to cover the withdrawal amount.
    /// - The withdrawal amount must be greater than zero.
    ///
    /// Emits a `Withdraw` event.
    ///
    /// @param _amount The amount to be withdrawn.
    function _withdraw(uint256 _amount) internal {
        //Assert withdrawer has enough balance
        if(balanceOf(msg.sender) < _amount) {
            revert Errors.InsufficientBalance({ 
                currentBalance: balanceOf(msg.sender), 
                amount: _amount 
            });
        }

        //Assert something is being withdrawn
        if(_amount == 0) {
            revert Errors.ZeroAmount({ amount: _amount });
        }

        // Get baseAsset value from the amount of shares.
        // This is the amount that the user wants to receive.
        uint256 balanceToWithdraw = _shareValue(_amount);

        //If the amount the user wants to withdraw is higher than the amount of
        //idle assets on the multistrategy, withdraw from strategies
        if(balanceToWithdraw > IERC20(asset()).balanceOf(address(this))) {
            for(uint8 i = 0; i <= withdrawOrder.length;){
                address strategy = withdrawOrder[i];

                // We reached the end of the withdraw queue
                if(strategy == address(0)){
                    break;
                }

                // Get the current balance of this contract
                uint256 balanceBeforeWithdraw = IERC20(asset()).balanceOf(address(this));

                // Ask for the strategy to send a report, as it could have an unlrealised Gain or Loss.
                IStrategyAdapter(strategy).askReport();

                // Update the balance to withdraw as a strategy could have made a loss so the withdrawer
                // must take a cut too.
                balanceToWithdraw = _shareValue(_amount);

                // If this condition is true, multistrategy now holds enough to cover the withdraw, 
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
                uint256 withdrawn = IERC20(asset()).balanceOf(address(this)) - balanceBeforeWithdraw;

                // Reduce the strategy's and multistretegy's totalDebt
                strategies[strategy].totalDebt -= withdrawn;
                totalDebt -= withdrawn;

                unchecked { ++i; }
            }

            uint256 currentBalance = IERC20(asset()).balanceOf(address(this));

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
        IERC20(asset()).safeTransfer(msg.sender, balanceToWithdraw);

        emit Withdraw(balanceToWithdraw);
    }

    /// @notice Internal function to request credit for an active strategy.
    /// 
    /// This function performs the following actions:
    /// - Calculates the available credit for the strategy using `_creditAvailable`.
    /// - If credit is available, it updates the total debt for the strategy and the multistrategy contract.
    /// - Transfers the calculated credit amount to the strategy.
    ///
    /// Requirements:
    /// - The contract must not be paused.
    /// - The caller must be an active strategy.
    ///
    /// Emits a `CreditRequested` event.
    ///
    /// @dev This function should be called only by active strategies when they need to request credit.
    function _requestCredit() internal returns (uint256 credit){
        credit = _creditAvailable(msg.sender);

        // Check that the strategy has some credit available
        if(credit > 0) {

            // Update the total debt of the strategy and multistrategy
            strategies[msg.sender].totalDebt += credit;
            totalDebt += credit;

            // Transfer the credit to the strategy
            IERC20(asset()).safeTransfer(msg.sender, credit);

            emit CreditRequested(msg.sender, credit);
        }

        return credit;
    }

    /// @notice Internal function to report the performance of a strategy.
    /// 
    /// This function performs the following actions:
    /// - Validates that the reporting strategy does not claim both a gain and a loss simultaneously.
    /// - Checks that the strategy has sufficient tokens to cover the debt repayment and the gain.
    /// - If there is a loss, it realizes the loss.
    /// - Calculates and deducts the performance fee from the gain, transferring it to the fee recipient.
    /// - Transfers the remaining profit to the contract.
    /// - Determines the excess debt of the strategy and repays it up to the amount available.
    /// - Adjusts the strategy's and contract's total debt accordingly.
    /// - Calculates and updates the new locked profit after accounting for any losses.
    /// - Updates the reporting timestamps for the strategy and the contract.
    ///
    /// Requirements:
    /// - The contract must not be paused.
    /// - The function must be called by an active strategy.
    /// - The strategy must not report both gain and loss simultaneously.
    /// - The strategy must have enough balance to cover the gain and debt repayment.
    ///
    /// Emits a `StrategyReported` event.
    ///
    /// @param _debtRepayment The amount of debt being repaid by the strategy.
    /// @param _gain The amount of profit reported by the strategy.
    /// @param _loss The amount of loss reported by the strategy.
    function _report(uint256 _debtRepayment, uint256 _gain, uint256 _loss) internal {
        // Check that the strategy isn't reporting a gain and a loss at the same time.
        if(_gain > 0 && _loss > 0) {
            revert Errors.GainLossMissmatch();
        }

        // Check that the strategy actually has the tokens to transfer the profits and repay the debt.
        if(IERC20(asset()).balanceOf(msg.sender) < _debtRepayment + _gain) {
            revert Errors.InsufficientBalance({ 
                currentBalance: IERC20(asset()).balanceOf(msg.sender),
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
                IERC20(asset()).safeTransferFrom(msg.sender, protocolFeeRecipient, pFee);
            }

            // Transfer the profit from the strategy to this multistrategy.
            profit = _gain - pFee;
            IERC20(asset()).safeTransferFrom(msg.sender, address(this), profit);
        } 

        uint256 exceedingDebt = _debtExcess(msg.sender);
        uint256 debtToRepay = Math.min(_debtRepayment, exceedingDebt);

        // If the strategy has made any funds available for repayment and the strategy has more debt
        // than it should, the strategy will repay the debt with the funds that has made available
        // or up to the amount that would remove the excess of debt.
        if(debtToRepay > 0) {
            strategies[msg.sender].totalDebt -= debtToRepay;
            totalDebt -= debtToRepay;

            IERC20(asset()).safeTransferFrom(msg.sender, address(this), debtToRepay);
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

    /// @notice Internal function to report a loss for a strategy.
    /// 
    /// This function performs the following actions:
    /// - Validates that the loss reported by the strategy does not exceed its total debt.
    /// - Updates the strategy's total loss by adding the reported loss.
    /// - Reduces the strategy's total debt by the reported loss.
    /// - Adjusts the contract's total debt by reducing it with the reported loss.
    /// 
    /// Requirements:
    /// - The reported loss must not exceed the strategy's total debt.
    ///
    /// @param _strategy The address of the strategy reporting the loss.
    /// @param _loss The amount of loss reported by the strategy.
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

    /// @notice Internal function to issue shares equivalent to a given amount for a recipient.
    /// 
    /// This function performs the following actions:
    /// - Calculates the number of shares to issue based on the current total supply and free funds.
    /// - If the total supply is greater than zero, the shares are proportional to the amount and total supply.
    /// - If the total supply is zero, the shares are equal to the amount.
    /// - Mints the calculated number of shares for the recipient.
    /// 
    /// @param _amount The amount of funds for which shares are to be issued.
    /// @param _recipient The address of the recipient to receive the issued shares.
    function _issueSharesForAmount(uint256 _amount, address _recipient) internal {
        uint256 shares = 0;
        uint256 totalSupply = totalSupply();

        if(totalSupply > 0) {
            shares = Math.mulDiv(_amount, totalSupply, _freeFunds());
        } else {
            shares = _amount;
        }

        _mint(_recipient, _amount);
    }

    /// @notice Internal function to rescue tokens from the contract.
    /// 
    /// This function performs the following actions:
    /// - Retrieves the balance of the specified token in the contract.
    /// - Transfers the entire balance of the specified token to the recipient address.
    ///
    /// Requirements:
    /// - The caller must be the guardian.
    /// - The specified token must not be the base asset to prevent unauthorized withdrawals.
    ///
    /// @param _token The address of the token to be rescued.
    /// @param _recipient The address to receive the rescued tokens.
    function _rescueToken(address _token, address _recipient) internal {
        // Check that we aren't stealing from the multistrategy.
        if(_token == asset()) {
            revert Errors.InvalidAddress(_token);
        }

        uint256 amount = IERC20(_token).balanceOf(address(this));
        IERC20(_token).safeTransfer(_recipient, amount);
    }
}