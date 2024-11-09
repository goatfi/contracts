// SPDX-License-Identifier: GNU AGPLv3

pragma solidity 0.8.27;

import { 
    IERC20,
    IERC4626,
    ERC20,
    ERC4626
} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { MultistrategyManageable } from "src/abstracts/MultistrategyManageable.sol";
import { IMultistrategy } from "interfaces/infra/multistrategy/IMultistrategy.sol";
import { IStrategyAdapter } from "interfaces/infra/multistrategy/IStrategyAdapter.sol";
import { Errors } from "src/infra/libraries/Errors.sol";

contract Multistrategy is IMultistrategy, MultistrategyManageable, ERC4626, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using Math for uint256;

    /// @inheritdoc IMultistrategy
    uint256 public lastReport;

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
        performanceFee = 1000;
        lastReport = block.timestamp;
    }

    /*//////////////////////////////////////////////////////////////////////////
                        USER FACING CONSTANT FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @inheritdoc IERC4626
    function totalAssets() public view override returns (uint256) {
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
        if(_assets <= _liquidity()) {
            return shares;
        } else {
            if(slippageLimit == MAX_BPS) return type(uint256).max;
            // Return the number of shares required at the current rate, accounting for slippage.
            return shares.mulDiv(MAX_BPS, MAX_BPS - slippageLimit, Math.Rounding.Ceil);
        }
    }

    /// @inheritdoc IERC4626
    function previewRedeem(uint256 _shares) public view override returns (uint256) {
        uint256 assets = _convertToAssets(_shares, Math.Rounding.Floor);
        if(assets <= _liquidity()) {
            return assets;
        } else {
            // Return the number of assets redeemable at the maximum permitted slippage.
            return assets.mulDiv(MAX_BPS - slippageLimit, MAX_BPS, Math.Rounding.Floor);
        }
    }

    /// @inheritdoc IMultistrategy
    function pricePerShare() external view returns (uint256) {
        return convertToAssets(1 ether);
    }

    /// @inheritdoc IMultistrategy
    function creditAvailable(address _strategy) external view returns (uint256) {
        return _creditAvailable(_strategy);
    }

    /// @inheritdoc IMultistrategy
    function debtExcess(address _strategy) external view returns (uint256) {
        return _debtExcess(_strategy);
    }

    /// @inheritdoc IMultistrategy
    function strategyTotalDebt(address _strategy) external view returns (uint256) {
        return strategies[_strategy].totalDebt;
    }

    /*//////////////////////////////////////////////////////////////////////////
                        USER FACING NON-CONSTANT FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @inheritdoc IERC4626
    function deposit(uint256 _assets, address _receiver) public override whenNotPaused nonReentrant returns (uint256) {
        _preDeposit();

        uint256 maxAssets = maxDeposit(_receiver);
        require(_assets <= maxAssets, ERC4626ExceededMaxDeposit(_receiver, _assets, maxAssets));

        uint256 shares = previewDeposit(_assets);
        _deposit(msg.sender, _receiver, _assets, shares);

        return shares;
    }

    /// @inheritdoc IERC4626
    function mint(uint256 _shares, address _receiver) public override whenNotPaused nonReentrant returns (uint256) {
        _preDeposit();

        uint256 maxShares = maxMint(_receiver);
        require(_shares <= maxShares, ERC4626ExceededMaxMint(_receiver, _shares, maxShares));

        uint256 assets = previewMint(_shares);
        _deposit(msg.sender, _receiver, assets, _shares);

        return assets;
    }

    /// @inheritdoc IERC4626
    function withdraw(uint256 _assets, address _receiver, address _owner) public override whenNotPaused nonReentrant returns (uint256) {
        uint256 maxAssets = maxWithdraw(_owner);
        require(_assets <= maxAssets, ERC4626ExceededMaxWithdraw(_owner, _assets, maxAssets));

        uint256 maxShares = previewWithdraw(_assets);
        (, uint256 shares) = _withdraw(msg.sender, _receiver, _owner, _assets, maxShares, false);

        require(shares <= maxShares, Errors.SlippageCheckFailed(maxShares, shares));

        return shares;
    }

    /// @inheritdoc IERC4626
    function redeem(uint256 _shares, address _receiver, address _owner) public override whenNotPaused nonReentrant returns (uint256) {
        uint256 maxShares = maxRedeem(_owner);
        require(_shares <= maxShares, ERC4626ExceededMaxRedeem(_owner, _shares, maxShares));

        uint256 minAssets = previewRedeem(_shares);
        (uint256 assets, ) = _withdraw(msg.sender, _receiver, _owner, minAssets, _shares, true);

        require(assets >= minAssets, Errors.SlippageCheckFailed(minAssets, assets));

        return assets;
    }

    /// @inheritdoc IMultistrategy
    function requestCredit() external whenNotPaused onlyActiveStrategy(msg.sender) returns (uint256) {
        return _requestCredit();
    }

    /// @inheritdoc IMultistrategy
    function strategyReport(uint256 _debtRepayment, uint256 _gain, uint256 _loss) 
        external 
        whenNotPaused
        onlyActiveStrategy(msg.sender)
    {
        _report(_debtRepayment, _gain, _loss);
    }

    /// @inheritdoc IMultistrategy
    function rescueToken(address _token, address _recipient) external onlyGuardian {
        _rescueToken(_token, _recipient);
    }

    /*//////////////////////////////////////////////////////////////////////////
                            INTERNAL CONSTANT FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Internal view function to retrieve the current liquidity of the contract.
    /// @return The current liquidity (balance of the asset) of the contract.
    function _liquidity() internal view returns (uint256) {
        return IERC20(asset()).balanceOf(address(this));
    }

    /// @notice Converts a given amount of assets to shares, with specified rounding.
    /// @param _assets The amount of assets to convert to shares.
    /// @param rounding The rounding direction to apply during the conversion.
    /// @return The number of shares corresponding to the given amount of assets.
    function _convertToShares(uint256 _assets, Math.Rounding rounding) internal view override returns (uint256) {
        return _assets.mulDiv(totalSupply() + 10 ** _decimalsOffset(), totalAssets() + 1, rounding);
    }

    /// @notice Convert a given amount of shares to assets, with specified rounding.
    /// @param _shares The number of shares to convert to assets.
    /// @param rounding The rounding direction to apply during the conversion.
    /// @return The amount of assets corresponding to the given number of shares.
    function _convertToAssets(uint256 _shares, Math.Rounding rounding) internal view override returns (uint256) {
        return _shares.mulDiv(totalAssets() + 1, totalSupply() + 10 ** _decimalsOffset(), rounding);
    }

    /// @notice Calculates the available credit for a strategy.
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
    function _creditAvailable(address _strategy) internal view returns (uint256) {
        uint256 mult_totalAssets = totalAssets();
        uint256 mult_debtLimit = debtRatio.mulDiv(mult_totalAssets, MAX_BPS);
        uint256 mult_totalDebt = totalDebt;

        uint256 strat_debtLimit = strategies[_strategy].debtRatio.mulDiv(mult_totalAssets, MAX_BPS);
        uint256 strat_totalDebt = strategies[_strategy].totalDebt;
        uint256 strat_minDebtDelta = strategies[_strategy].minDebtDelta;
        uint256 strat_maxDebtDelta = strategies[_strategy].maxDebtDelta;

        if(strat_totalDebt >= strat_debtLimit || mult_totalDebt >= mult_debtLimit){
            return 0;
        }

        uint256 credit = strat_debtLimit - strat_totalDebt;
        uint256 maxAvailableCredit = mult_debtLimit - mult_totalDebt;
        credit = Math.min(credit, maxAvailableCredit);

        // Bound to the minimum and maximum borrow limits
        if(credit < strat_minDebtDelta) {
            return 0;
        } else {
            return Math.min(credit, strat_maxDebtDelta);
        }
    }

    /// @notice Calculates the excess debt of a strategy.
    /// 
    /// This function performs the following actions:
    /// - If the overall debt ratio is zero, it returns the total debt of the strategy as excess debt.
    /// - Calculates the strategy's debt limit based on its debt ratio and the total assets.
    /// - If the strategy's total debt is less than or equal to its debt limit, it returns zero indicating no excess debt.
    /// - If the strategy's total debt exceeds its debt limit, it returns the difference as the excess debt.
    /// 
    /// @param _strategy The address of the strategy for which to determine the debt excess.
    /// @return The amount of excess debt for the given strategy.
    function _debtExcess(address _strategy) internal view returns (uint256) {
        if(debtRatio == 0) {
            return strategies[_strategy].totalDebt;
        }

        uint256 strat_debtLimit = strategies[_strategy].debtRatio.mulDiv(totalAssets(), MAX_BPS);
        uint256 strat_totalDebt = strategies[_strategy].totalDebt;

        if(strat_totalDebt <= strat_debtLimit) {
            return 0;
        } else {
            return strat_totalDebt - strat_debtLimit;
        }
    }

    /*//////////////////////////////////////////////////////////////////////////
                            INTERNAL NON-CONSTANT FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Prepares the contract for a deposit by requesting reports from active strategies.
    /// 
    /// This function performs the following actions:
    /// - If there are no active strategies, it returns immediately.
    /// - Iterates through the `withdrawOrder` array, which defines the order in which strategies are withdrawn from.
    /// - For each strategy in the `withdrawOrder`:
    ///   - If the strategy address is zero, it returns, indicating the end of the list.
    ///   - If the strategy has no debt, it skips to the next strategy.
    ///   - Otherwise, it requests the strategy to report its current state by calling `askReport`.
    ///
    /// @dev This function is called before a deposit to ensure that the strategies are up-to-date with their reports.
    function _preDeposit() internal {
        if (activeStrategies == 0) return;

        for(uint8 i = 0; i < activeStrategies; ++i){
            address strategy = withdrawOrder[i];
            if(strategy == address(0)) return;
            if(strategies[strategy].totalDebt == 0) continue;
            IStrategyAdapter(strategy).askReport();
        }
    }

    /// @notice Handles deposits into the contract.
    /// 
    /// This function performs the following actions:
    /// - Validates that the receiver address is not zero or the contract address itself.
    /// - Ensures that the deposited amount is greater than zero.
    /// - Transfers the assets from the caller to the contract.
    /// - Mints the corresponding shares for the receiver.
    /// - Emits a `Deposit` event with the caller, receiver, amount of assets, and number of shares.
    /// 
    /// @param _caller The address of the entity initiating the deposit.
    /// @param _receiver The address of the recipient to receive the shares.
    /// @param _assets The amount of assets being deposited.
    /// @param _shares The number of shares to be minted for the receiver.
    function _deposit(address _caller, address _receiver, uint256 _assets, uint256 _shares) internal override {
        require(_receiver != address(0) && _receiver != address(this), Errors.InvalidAddress(_receiver));
        require(_assets > 0, Errors.ZeroAmount(_assets));

        IERC20(asset()).safeTransferFrom(_caller, address(this), _assets);
        _mint(_receiver, _shares);

        emit Deposit(_caller, _receiver, _assets, _shares);
    }

    /// @notice Handles withdrawals from the contract.
    /// 
    /// This function performs the following actions:
    /// - If the caller is not the owner, it checks and spends the allowance for the withdrawal.
    /// - Ensures that the amount to be withdrawn is greater than zero.
    /// - If the requested withdrawal amount exceeds the available liquidity, it withdraws the necessary amount from the strategies in the withdrawal order.
    ///   - Iterates through the withdrawal queue, withdrawing from each strategy until the liquidity requirement is met or the queue is exhausted.
    ///   - Updates the total debt of both the strategy and the contract as assets are withdrawn.
    ///   - Requests the strategy to report, accounting for potential gains or losses.
    /// - Reverts if the withdrawal process does not result in sufficient liquidity.
    /// - Burns the corresponding shares and transfers the requested assets to the receiver.
    /// - Emits a `Withdraw` event with the caller, receiver, owner, amount of assets withdrawn, and shares burned.
    /// 
    /// @param _caller The address of the entity initiating the withdrawal.
    /// @param _receiver The address of the recipient to receive the withdrawn assets.
    /// @param _owner The address of the owner of the shares being withdrawn.
    /// @param _assets The amount of assets to withdraw.
    /// @param _shares The amount of shares to burn.
    /// @param _consumeAllShares True if all `_shares` should be used to withdraw. False if it should withdraw just `_assets`.
    /// @return The number of assets withdrawn and the shares burned as a result of the withdrawal.
    function _withdraw(
        address _caller,
        address _receiver,
        address _owner,
        uint256 _assets,
        uint256 _shares,
        bool _consumeAllShares
    ) internal returns (uint256, uint256) {
        require(_shares > 0, Errors.ZeroAmount(_shares));

        if (_caller != _owner) {
            _spendAllowance(_owner, _caller, _shares);
        }

        uint256 assets = _consumeAllShares ? _convertToAssets(_shares, Math.Rounding.Floor) : _assets;

        if(assets > _liquidity()) {
            for(uint8 i = 0; i < withdrawOrder.length; ++i){
                address strategy = withdrawOrder[i];

                // We reached the end of the withdraw queue and assets are still higher than the liquidity
                require(strategy != address(0), Errors.InsufficientLiquidity(assets, _liquidity()));

                // We can't withdraw from a strategy more than what it has asked as credit.
                uint256 assetsToWithdraw = Math.min(assets - _liquidity(), strategies[strategy].totalDebt);
                if(assetsToWithdraw == 0) continue;

                uint256 withdrawn = IStrategyAdapter(strategy).withdraw(assetsToWithdraw);
                strategies[strategy].totalDebt -= withdrawn;
                totalDebt -= withdrawn;

                IStrategyAdapter(strategy).askReport();

                // Update assets, as a loss could have been reported and user should get less assets for
                // the same amount of shares.
                if(_consumeAllShares) assets = _convertToAssets(_shares, Math.Rounding.Floor);
                if(assets <= _liquidity()) break;
            }
        }

        uint256 shares = _consumeAllShares ? _shares : _convertToShares(assets, Math.Rounding.Ceil);
        _burn(_owner, shares);
        IERC20(asset()).safeTransfer(_receiver, assets);

        emit Withdraw(_caller, _receiver, _owner, assets, shares);

        return (assets, shares);
    }

    /// @notice Requests credit for an active strategy.
    /// 
    /// This function performs the following actions:
    /// - Calculates the available credit for the strategy using `_creditAvailable`.
    /// - If credit is available, it updates the total debt for the strategy and the multistrategy contract.
    /// - Transfers the calculated credit amount to the strategy.
    ///
    /// Emits a `CreditRequested` event.
    ///
    /// @dev This function should be called only by active strategies when they need to request credit.
    function _requestCredit() internal returns (uint256){
        uint256 credit = _creditAvailable(msg.sender);

        if(credit > 0) {
            strategies[msg.sender].totalDebt += credit;
            totalDebt += credit;
            IERC20(asset()).safeTransfer(msg.sender, credit);
            emit CreditRequested(msg.sender, credit);
        }
        
        return credit;
    }

    /// @notice Reports the performance of a strategy.
    /// 
    /// This function performs the following actions:
    /// - Validates that the reporting strategy does not claim both a gain and a loss simultaneously.
    /// - Checks that the strategy has sufficient tokens to cover the debt repayment and the gain.
    /// - If there is a loss, it realizes the loss.
    /// - Calculates and deducts the performance fee from the gain.
    /// - Determines the excess debt of the strategy.
    /// - Adjusts the strategy's and contract's total debt accordingly.
    /// - Calculates and updates the new locked profit after accounting for any losses.
    /// - Updates the reporting timestamps for the strategy and the contract.
    /// - Transfers the debt repayment and the gains to this contract.
    ///
    /// Emits a `StrategyReported` event.
    ///
    /// @param _debtRepayment The amount of debt being repaid by the strategy.
    /// @param _gain The amount of profit reported by the strategy.
    /// @param _loss The amount of loss reported by the strategy.
    function _report(uint256 _debtRepayment, uint256 _gain, uint256 _loss) internal {
        uint256 strategyBalance = IERC20(asset()).balanceOf(msg.sender);
        require(!(_gain > 0 && _loss > 0), Errors.GainLossMismatch());
        require(strategyBalance >= _debtRepayment + _gain, Errors.InsufficientBalance(strategyBalance, _debtRepayment + _gain));

        uint256 profit = 0;
        uint256 feesCollected = 0;
        if(_loss > 0) _reportLoss(msg.sender, _loss);
        if(_gain > 0) {
            feesCollected = _gain.mulDiv(performanceFee, MAX_BPS);
            profit = _gain - feesCollected;
            strategies[msg.sender].totalGain += _gain;
        } 

        uint256 debtToRepay = Math.min(_debtRepayment, _debtExcess(msg.sender));
        if(debtToRepay > 0) {
            strategies[msg.sender].totalDebt -= debtToRepay;
            totalDebt -= debtToRepay;
        }

        strategies[msg.sender].lastReport = block.timestamp;
        lastReport = block.timestamp;

        if(debtToRepay + _gain > 0) IERC20(asset()).safeTransferFrom(msg.sender, address(this), debtToRepay + _gain);
        if(feesCollected > 0) IERC20(asset()).safeTransfer(protocolFeeRecipient, feesCollected);

        emit StrategyReported(msg.sender, debtToRepay, profit, _loss);
    }

    /// @notice Reports a loss for a strategy.
    /// 
    /// This function performs the following actions:
    /// - Validates that the loss reported by the strategy does not exceed its total debt.
    /// - Updates the strategy's total loss by adding the reported loss.
    /// - Reduces the strategy's total debt by the reported loss.
    /// - Adjusts the contract's total debt by reducing it with the reported loss.
    ///
    /// @param _strategy The address of the strategy reporting the loss.
    /// @param _loss The amount of loss reported by the strategy.
    function _reportLoss(address _strategy, uint256 _loss) internal {
        require(_loss <= strategies[_strategy].totalDebt, Errors.InvalidStrategyLoss());

        strategies[_strategy].totalLoss += _loss;
        strategies[_strategy].totalDebt -= _loss;
        totalDebt -= _loss;
    }

    /// @notice Rescues tokens from the contract.
    /// 
    /// This function performs the following actions:
    /// - Retrieves the balance of the specified token in the contract.
    /// - Transfers the entire balance of the specified token to the recipient address.
    ///
    /// @param _token The address of the token to be rescued.
    /// @param _recipient The address to receive the rescued tokens.
    function _rescueToken(address _token, address _recipient) internal {
        require(_token != asset(), Errors.InvalidAddress(_token));

        uint256 amount = IERC20(_token).balanceOf(address(this));
        IERC20(_token).safeTransfer(_recipient, amount);
    }
}