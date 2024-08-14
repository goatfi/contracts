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
    using Math for uint256;
    
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
        return _liquidity() + totalDebt;
    }

    /// @inheritdoc IERC4626
    /// @dev Limited by the deposit limit
    function maxDeposit(address) public view override returns (uint256) {
        if(totalAssets() >= depositLimit) {
            return 0;
        } else {
            return depositLimit - totalAssets();
        }
    }

    /// @inheritdoc IERC4626
    /// @dev Limited by the deposit limit
    function maxMint(address _receiver) public view override returns (uint256) {
        return convertToShares(maxDeposit(_receiver));
    }

    /// @inheritdoc IERC4626
    function previewWithdraw(uint256 _assets) public view override returns (uint256) {
        uint256 shares = _convertToShares(_assets, Math.Rounding.Ceil);
        // If the liquidity is enough, return the amount of shares needed at current rate.
        if(_assets <= _liquidity()) {
            return shares;
        } else {
            // Otherwise, return the number of shares required at the current rate, accounting for slippage.
            // A withdrawal requiring more shares to get the amount of assets needed will revert.
            return shares.mulDiv(MAX_BPS + slippageLimit, MAX_BPS, Math.Rounding.Ceil);
        }
    }

    /// @inheritdoc IERC4626
    function previewRedeem(uint256 _shares) public view override returns (uint256) {
        uint256 assets = _convertToAssets(_shares, Math.Rounding.Floor);
        // If the liquidity is enough, return the amount of assets redeemed at current rate.
        if(assets <= _liquidity()) {
            return assets;
        } else {
            // Otherwise, return the number of assets redeemable at the maximum permitted slippage.
            // Any redemption resulting in fewer assets than this threshold will revert.
            return assets.mulDiv(MAX_BPS - slippageLimit, MAX_BPS, Math.Rounding.Floor);
        }
    }

    /// @inheritdoc IMultistrategy
    function pricePerShare() external view returns(uint256) {
        return convertToAssets(1 ether);
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
        _deposit(msg.sender, _receiver, _assets, shares);

        return shares;
    }

    /// @inheritdoc IERC4626
    function mint(uint256 _shares, address _receiver) public override whenNotPaused returns (uint256) {
        uint256 maxShares = maxMint(_receiver);
        if (_shares > maxShares) {
            revert ERC4626ExceededMaxMint(_receiver, _shares, maxShares);
        }

        uint256 assets = previewMint(_shares);
        _deposit(msg.sender, _receiver, assets, _shares);

        return assets;
    }

    /// @inheritdoc IERC4626
    function withdraw(uint256 _assets, address _receiver, address _owner) public override whenNotPaused returns (uint256) {
        uint256 maxAssets = maxWithdraw(_owner);
        if (_assets > maxAssets) {
            revert ERC4626ExceededMaxWithdraw(_owner, _assets, maxAssets);
        }

        uint256 maxShares = previewWithdraw(_assets);
        uint256 shares = _withdraw(msg.sender, _receiver, _owner, _assets);

        if(shares > maxShares) {
            revert Errors.SlippageCheckFailed(maxShares, shares);
        }

        return shares;
    }

    /// @inheritdoc IERC4626
    function redeem(uint256 _shares, address _receiver, address _owner) public override whenNotPaused returns (uint256) {
        uint256 maxShares = maxRedeem(_owner);
        if (_shares > maxShares) {
            revert ERC4626ExceededMaxRedeem(_owner, _shares, maxShares);
        }

        uint256 minAssets = previewRedeem(_shares);
        uint256 assets = _redeem(msg.sender, _receiver, _owner, _shares);

        if(assets < minAssets) {
            revert Errors.SlippageCheckFailed(minAssets, assets);
        }

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

    /// @notice Internal view function to retrieve the current liquidity of the contract.
    /// 
    /// This function performs the following actions:
    /// - Retrieves the balance of the asset held by the contract.
    /// 
    /// @return The current liquidity (balance of the asset) of the contract.
    function _liquidity() internal view returns(uint256) {
        return IERC20(asset()).balanceOf(address(this));
    }

    /// @notice Internal view function to calculate the number of shares corresponding to a given amount.
    /// 
    /// This function performs the following actions:
    /// - Retrieves the free funds available in the contract.
    /// - If there are free funds, calculates the shares as a proportion of the total supply to the free funds.
    /// - If there are no free funds, returns zero.
    /// 
    /// @param _assets The amount for which to calculate the corresponding shares.
    /// @return The number of shares corresponding to the given amount.
    function _convertToShares(uint256 _assets, Math.Rounding rounding) internal view override returns(uint256) {
        return _assets.mulDiv(totalSupply() + 10 ** _decimalsOffset(), _freeFunds() + 1, rounding);
    }

    /// @notice Internal view function to calculate the value of a given number of shares.
    /// 
    /// This function performs the following actions:
    /// - If the total supply of shares is zero, returns the number of shares as the value.
    /// - Otherwise, calculates the value of the shares as a proportion of the free funds to the total supply.
    /// 
    /// @param _shares The number of shares to calculate the value for.
    /// @return The value corresponding to the given number of shares.
    function _convertToAssets(uint256 _shares, Math.Rounding rounding) internal view override returns(uint256) {
        return _shares.mulDiv(_freeFunds() + 1, totalSupply() + 10 ** _decimalsOffset(), rounding);
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
        uint256 mult_totalAssets = totalAssets();
        uint256 mult_debtLimit = debtRatio.mulDiv(mult_totalAssets, MAX_BPS);
        uint256 mult_totalDebt = totalDebt;

        uint256 strat_debtLimit = strategies[_strategy].debtRatio.mulDiv(mult_totalAssets, MAX_BPS);
        uint256 strat_totalDebt = strategies[_strategy].totalDebt;
        uint256 strat_minDebtDelta = strategies[_strategy].minDebtDelta;
        uint256 strat_maxDebtDelta = strategies[_strategy].maxDebtDelta;

        // If a strategy has borrowed more than what is permitted
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

        uint256 strat_debtLimit = strategies[_strategy].debtRatio.mulDiv(totalAssets(), MAX_BPS);
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
        return totalAssets() - _calculateLockedProfit();
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
            return lockedProfit - lockedFundsRatio.mulDiv(lockedProfit, DEGRADATION_COEFFICIENT);
        }
        return 0;
    }

    /*//////////////////////////////////////////////////////////////////////////
                            INTERNAL NON-CONSTANT FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Internal function to handle deposits into the contract.
    /// 
    /// This function performs the following actions:
    /// - Validates that the receiver address is not zero or the contract address itself.
    /// - Ensures that the deposited amount is greater than zero.
    /// - Checks that the deposit does not exceed the deposit limit.
    /// - Transfers the assets from the caller to the contract.
    /// - Mints the corresponding shares for the receiver.
    /// - Emits a `Deposit` event with the caller, receiver, amount of assets, and number of shares.
    /// 
    /// @param _caller The address of the entity initiating the deposit.
    /// @param _receiver The address of the recipient to receive the shares.
    /// @param _assets The amount of assets being deposited.
    /// @param _shares The number of shares to be minted for the receiver.
    function _deposit(address _caller, address _receiver, uint256 _assets, uint256 _shares) internal override {
        if(_receiver == address(0) || _receiver == address(this)) {
            revert Errors.InvalidAddress({ addr: _receiver });
        }
        // Assert something gets deposited
        if(_assets == 0) {
            revert Errors.ZeroAmount({ amount: _assets });
        }

        //Get funds from depositor
        IERC20(asset()).safeTransferFrom(_caller, address(this), _assets);
        //Mint shares
        _mint(_receiver, _shares);

        emit Deposit(_caller, _receiver, _assets, _shares);
    }

    
    function _withdraw(
        address _caller,
        address _receiver,
        address _owner,
        uint256 _assets
    ) internal returns (uint256) {
        if (_caller != _owner) {
            _spendAllowance(_owner, _caller, previewWithdraw(_assets));
        }

        // Assert something gets withdrawn
        if(_assets == 0) {
            revert Errors.ZeroAmount({ amount: _assets });
        }

        //If the amount the user wants to withdraw is higher than the amount of
        //idle assets on the multistrategy, withdraw from strategies
        if(_assets > _liquidity()) {
            for(uint8 i = 0; i <= withdrawOrder.length;){
                address strategy = withdrawOrder[i];

                // We reached the end of the withdraw queue
                if(strategy == address(0)){
                    break;
                }

                // We can't withdraw from a strategy more than what it has asked as credit.
                uint256 assetsToWithdraw = Math.min(_assets - _liquidity(), strategies[strategy].totalDebt);

                // Check that the strategy actually has something to withdraw
                if(assetsToWithdraw == 0) {
                    unchecked { ++i; }
                    continue;
                }

                // We withdraw from the strategy
                uint256 withdrawn = IStrategyAdapter(strategy).withdraw(assetsToWithdraw);

                // Reduce the strategy's and multistrategy totalDebt
                strategies[strategy].totalDebt -= withdrawn;
                totalDebt -= withdrawn;

                // Ask for the strategy to send a report, as it could have an unrealized loss due to slippage.
                // If the strategy has made a gain, the user withdrawing won't get the gains.
                IStrategyAdapter(strategy).askReport();

                if(_assets <= _liquidity()){
                    break;
                }

                unchecked { ++i; }
            }
        }

        // If the withdrawal process couldn't withdraw enough assets, revert.
        if(_assets > _liquidity()) {
            revert Errors.InsufficientLiquidity(_assets, _liquidity());
        }

        // Burn the shares and send the assets to the receiver
        uint256 shares = _convertToShares(_assets, Math.Rounding.Ceil);
        _burn(_owner, shares);
        IERC20(asset()).safeTransfer(_receiver, _assets);

        emit Withdraw(_caller, _receiver, _owner, _assets, shares);

        return shares;
    }

    function _redeem(
        address _caller,
        address _receiver,
        address _owner,
        uint256 _shares 
    ) internal returns (uint256) {
        if (_caller != _owner) {
            _spendAllowance(_owner, _caller, _shares);
        }

        // Assert something gets withdrawn
        if(_shares == 0) {
            revert Errors.ZeroAmount({ amount: _shares });
        }

        uint256 assets = _convertToAssets(_shares, Math.Rounding.Floor);

        if(assets > _liquidity()) {
            for(uint8 i = 0; i <= withdrawOrder.length;){
                address strategy = withdrawOrder[i];

                // We reached the end of the withdraw queue
                if(strategy == address(0)){
                    break;
                }

                // We can't withdraw from a strategy more than what it has asked as credit.
                uint256 assetsToWithdraw = Math.min(assets - _liquidity(), strategies[strategy].totalDebt);

                // Check that the strategy actually has something to withdraw
                if(assetsToWithdraw == 0) {
                    unchecked { ++i; }
                    continue;
                }

                // We withdraw from the strategy
                uint256 withdrawn = IStrategyAdapter(strategy).withdraw(assetsToWithdraw);

                // Reduce the strategy's and multistrategy totalDebt
                strategies[strategy].totalDebt -= withdrawn;
                totalDebt -= withdrawn;

                // Ask for the strategy to send a report, as it could have an unrealized Gain or Loss.
                IStrategyAdapter(strategy).askReport();

                // Convert the shares to assets, because if a loss was realized, the liquidity could be
                // enough as less assets are given for the same amount of shares.
                assets = _convertToAssets(_shares, Math.Rounding.Floor);

                // If this condition is true, multistrategy now holds enough to cover the withdraw, 
                // so we're done withdrawing from strategies.
                if(assets <= _liquidity()){
                    break;
                }

                unchecked { ++i; }
            }
        }

        // Burn the shares and send the assets to the receiver
        _burn(_owner, _shares);
        IERC20(asset()).safeTransfer(_receiver, assets);

        emit Withdraw(_caller, _receiver, _owner, assets, _shares);

        return assets;
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
            revert Errors.GainLossMismatch();
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
            uint256 pFee = _gain.mulDiv(performanceFee, MAX_BPS);

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
        
        // If the loss is smaller than the locked profit, we reduce it by the loss the strategy has realized.
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