// SPDX-License-Identifier: GNU AGPLv3

pragma solidity >=0.8.20 <= 0.9.0;

import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import { IERC20, SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { StrategyAdapterAdminable } from "src/abstracts/StrategyAdapterAdminable.sol";
import { IStrategyAdapter } from "interfaces/infra/multistrategy/IStrategyAdapter.sol";
import { IMultistrategy } from "interfaces/infra/multistrategy/IMultistrategy.sol";
import { IMultistrategyManageable } from "interfaces/infra/multistrategy/IMultistrategyManageable.sol";
import { Errors } from "src/infra/libraries/Errors.sol";

abstract contract StrategyAdapter is IStrategyAdapter, StrategyAdapterAdminable {
    using SafeERC20 for IERC20;

    /// @dev 100% in BPS, setting the slippage to 100% means no slippage protection.
    uint256 constant MAX_SLIPPAGE = 10_000;

    /// @inheritdoc IStrategyAdapter
    address public immutable multistrategy;

    /// @inheritdoc IStrategyAdapter
    address public immutable asset;

    /// @inheritdoc IStrategyAdapter
    uint256 public slippageLimit;

    /*//////////////////////////////////////////////////////////////////////////
                                     CONSTRUCTOR
    //////////////////////////////////////////////////////////////////////////*/
    
    /// @dev Reverts if `_baseAsset` doesn't match `baseAsset` on the Multistrategy.
    /// @param _multistrategy Address of the multistrategy this strategy will belongs to.
    /// @param _asset Address of the token used to deposit and withdraw on this strategy.
    constructor(address _multistrategy, address _asset) StrategyAdapterAdminable(msg.sender) {
        if(IERC4626(_multistrategy).asset() != _asset) {
            revert Errors.AssetMismatch({
                multAsset: IERC4626(_multistrategy).asset(),
                stratAsset: _asset
            });
        }

        multistrategy = _multistrategy;
        asset = _asset;
        slippageLimit = 0;

        IERC20(asset).forceApprove(multistrategy, type(uint256).max);
    }

    /// @dev Reverts if called by any account other than the Multistrategy this strategy belongs to.
    modifier onlyMultistrategy() {
        if(msg.sender != multistrategy) {
            revert Errors.CallerNotMultistrategy(msg.sender);
        }
        _;
    }

    /*//////////////////////////////////////////////////////////////////////////
                        USER FACING CONSTANT FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @inheritdoc IStrategyAdapter
    function totalAssets() external view returns(uint256) {
        return _totalAssets();
    }

    /*//////////////////////////////////////////////////////////////////////////
                        USER FACING NON-CONSTANT FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @inheritdoc IStrategyAdapter
    function requestCredit() external onlyOwner whenNotPaused {
        // Ask the Multistrategy for a credit
        uint256 credit = IMultistrategy(multistrategy).requestCredit();

        // If the credit is greater than 0, deposit into the underlying strategy.
        if(credit > 0) {
            _deposit();
        }
    }

    /// @inheritdoc IStrategyAdapter
    function setSlippageLimit(uint256 _slippageLimit) external onlyOwner {
        // Revert if the slippage limit is higher than 100%
        if(_slippageLimit > MAX_SLIPPAGE) {
            revert Errors.SlippageLimitExceeded(_slippageLimit);
        }

        slippageLimit = _slippageLimit;

        emit SlippageLimitSet(_slippageLimit);
    }
    
    /// @inheritdoc IStrategyAdapter
    function sendReport(uint256 _repayAmount) external onlyOwner whenNotPaused {
        _sendReport(_repayAmount);
    }

    /// @inheritdoc IStrategyAdapter
    function askReport() external onlyMultistrategy whenNotPaused {
        _sendReport(0);
    }

    /// @inheritdoc IStrategyAdapter
    function sendReportPanicked() external onlyOwner whenPaused {
        _sendReportPanicked();
    }

    /// @inheritdoc IStrategyAdapter
    function withdraw(uint256 _amount) external onlyMultistrategy whenNotPaused returns (uint256) {
        uint256 withdrawn = _tryWithdraw(_amount);

        IERC20(asset).safeTransfer(multistrategy, withdrawn);

        return withdrawn;
    }

    /// @inheritdoc IStrategyAdapter
    function panic() external onlyGuardian {
        _emergencyWithdraw();
        _revokeAllowances();
        _pause();
    }

    /// @inheritdoc IStrategyAdapter
    function pause() external onlyGuardian {
        _pause();
    }

    /// @inheritdoc IStrategyAdapter
    function unpause() external onlyOwner {
        _unpause();
        _giveAllowances();
    }

    /*//////////////////////////////////////////////////////////////////////////
                            INTERNAL CONSTANT FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Internal view function to calculate the gain and loss based on current assets.
    /// 
    /// This function performs the following actions:
    /// - Retrieves the total debt of the strategy from the multi-strategy contract.
    /// - Determines whether the current assets are greater than or equal to the total debt to calculate the gain.
    /// - If the current assets are less than the total debt, calculates the loss.
    /// 
    /// @param _currentAssets The current assets held by the strategy.
    /// @return gain The calculated gain.
    /// @return loss The calculated loss.
    function _calculateGainAndLoss(uint256 _currentAssets) internal view returns(uint256 gain, uint256 loss) {
        uint256 totalDebt = IMultistrategy(multistrategy).strategyTotalDebt(address(this));

        // Check if the strategy has made a gain or a loss
        if(_currentAssets >= totalDebt) {
            gain = _currentAssets - totalDebt;
        } else {
            loss = totalDebt - _currentAssets;
        }

        return (gain, loss);
    }

    /// @notice Internal view function to calculate the amount to be withdrawn from the strategy.
    /// 
    /// This function performs the following actions:
    /// - Retrieves the exceeding debt of the strategy from the multi-strategy contract.
    /// - If there is exceeding debt and a repayment amount is specified:
    ///   - Calculates the amount to be withdrawn to repay the exceeding debt at maximum slippage.
    ///   - Ensures the amount to be withdrawn does not exceed the repayment amount, adding any strategy gain.
    /// - If there is no exceeding debt or no repayment amount, returns the strategy gain as the amount to be withdrawn.
    ///   - Note that slippage calculations are not applied here as any slippage would be considered a loss and subtracted from the gain.
    /// 
    /// @param _repayAmount The amount to be repaid.
    /// @param _strategyGain The gain of the strategy.
    /// @return The amount to be withdrawn from the strategy.
    function _calculateAmountToBeWithdrawn(uint256 _repayAmount, uint256 _strategyGain) internal view returns(uint256) 
    {   
        // Get this strategy exceeding debt
        uint256 exceedingDebt = IMultistrategy(multistrategy).debtExcess(address(this));
        
        // If this strategy has exceeding debt and wants to repay it
        if(exceedingDebt > 0 && _repayAmount > 0) {
            // Calculate the amount to be withdrawn to repay the exceeding debt at max slippage
            uint256 exceedingDebtWithSlippage = Math.mulDiv(exceedingDebt, MAX_SLIPPAGE, MAX_SLIPPAGE - slippageLimit);

            // Only withdraw up to the amount this strategy manager wants to make available, plus any gains
            return Math.min(_repayAmount, exceedingDebtWithSlippage) + _strategyGain;
        } 

        return _strategyGain;
    }

    /// @notice Return the amount of `baseAsset` the underlying strategy holds. In the case this strategy
    /// has swapped `baseAsset` for another asset, it should return the most approximate value.
    /// @dev Child contract must implement the logic to calculate the amount of assets.
    function _totalAssets() internal virtual view returns(uint256) {}

    /*//////////////////////////////////////////////////////////////////////////
                            INTERNAL NON-CONSTANT FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Internal function to send a report on the strategy's performance.
    /// 
    /// This function performs the following actions:
    /// - Calculates the current assets of the strategy.
    /// - Attempts to withdraw the repayment amount plus any gain.
    /// - Ensures that the gain is not used to repay the debt.
    /// - Reports the available amount for repayment, the gain, and the loss to the multi-strategy.
    /// 
    /// @param _repayAmount The amount to be repaid to the multi-strategy.
    function _sendReport(uint256 _repayAmount) internal {
        uint256 currentAssets = _totalAssets();
        (uint256 gain, uint256 loss) = _calculateGainAndLoss(currentAssets);
        uint256 toBeWithdrawn = _calculateAmountToBeWithdrawn(_repayAmount, gain);

        // Withdraw the desired amount to repay plus the gain.
        uint256 withdrawn = _tryWithdraw(toBeWithdrawn);

        // Gain shouldn't be used to repay the debt
        uint256 availableForRepay = withdrawn - gain;
        //Report to the strategy
        IMultistrategy(multistrategy).strategyReport(availableForRepay, gain, loss);
    }

    /// @notice Internal function to send a report on the strategy's performance after the strategy
    ///         has been panicked.
    /// 
    /// This function performs the following actions:
    /// - Retrieves the current balance of the base asset held by the contract.
    /// - Calculates the gain and loss based on the current assets.
    /// - Ensures that the gain is not used to repay the debt.
    /// - Reports the available amount for repayment, the gain, and the loss to the multi-strategy.
    function _sendReportPanicked() internal {
        uint256 currentAssets = IERC20(asset).balanceOf(address(this));
        (uint256 gain, uint256 loss) = _calculateGainAndLoss(currentAssets);

        // Gain shouldn't be used to repay the debt
        uint256 availableForRepay = currentAssets - gain;

        //Report to the strategy
        IMultistrategy(multistrategy).strategyReport(availableForRepay, gain, loss);
    }

    /// @notice Internal function to attempt to withdraw a specified amount from the strategy.
    /// 
    /// This function performs the following actions:
    /// - Calls the internal `_withdraw` function to withdraw the desired amount.
    /// - Checks the current balance of the contract after the withdrawal.
    /// - If the balance is less than the desired amount, it reverts with an insufficient balance error.
    /// 
    /// @param _amount The amount to withdraw from the strategy.
    /// @return The amount withdrawn from the strategy.
    function _tryWithdraw(uint256 _amount) internal returns (uint256){
        // Withdraw the desired amount
        _withdraw(_amount);

        // Check that the strategy was able to withdraw the desired amount
        uint256 currentBalance = IERC20(asset).balanceOf(address(this));
        uint256 desiredBalance = Math.mulDiv(_amount, MAX_SLIPPAGE - slippageLimit, MAX_SLIPPAGE);
        if(currentBalance < desiredBalance) {
            // If it hasn't been able, revert.
            revert Errors.SlippageCheckFailed(desiredBalance, currentBalance);
        }

        return currentBalance;
    }

    /// @notice Deposit the entire balance of `baseAsset` this contract holds into the underlying strategy. 
    /// @dev Child contract must implement the logic that will put the funds to work.
    function _deposit() internal virtual {}

    /// @notice Withdraws the specified `_amount` of `baseAsset` from the underlying strategy. 
    /// @dev Child contract must implement the logic that will withdraw the funds.
    /// @param _amount The amount of `baseAsset` to withdraw.
    function _withdraw(uint256 _amount) internal virtual {}

    /// @notice Withdraws as much funds as possible from the underlying strategy.
    /// @dev Child contract must implement the logic to withdraw as much funds as possible.
    /// The withdraw process shouldn't have a slippage check, as it is in an emergency situation.
    function _emergencyWithdraw() internal virtual {}

    /// @dev Internal function to grant allowance for `baseAsset` to the contracts used by the strategy adapter.
    /// It should be overridden by derived contracts to specify the exact contracts and amounts for the allowances.
    function _giveAllowances() internal virtual {}

    /// @dev Internal function to revoke all previously granted allowances for `baseAsset`.
    /// It should be overridden by derived contracts to specify the exact contracts from which allowances are revoked.
    function _revokeAllowances() internal virtual {}
}