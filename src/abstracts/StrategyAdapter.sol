// SPDX-License-Identifier: GNU AGPLv3

pragma solidity 0.8.27;

import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import { IERC20, SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { StrategyAdapterAdminable } from "src/abstracts/StrategyAdapterAdminable.sol";
import { IStrategyAdapter } from "interfaces/infra/multistrategy/IStrategyAdapter.sol";
import { IMultistrategy } from "interfaces/infra/multistrategy/IMultistrategy.sol";
import { Errors } from "src/infra/libraries/Errors.sol";

abstract contract StrategyAdapter is IStrategyAdapter, StrategyAdapterAdminable {
    using SafeERC20 for IERC20;
    using Math for uint256;

    /// @dev 100% in BPS, setting the slippage to 100% means no slippage protection.
    uint256 constant MAX_SLIPPAGE = 10_000;

    /// @inheritdoc IStrategyAdapter
    address public immutable multistrategy;

    /// @inheritdoc IStrategyAdapter
    address public immutable asset;

    /// @inheritdoc IStrategyAdapter
    uint256 public slippageLimit;

    /// @notice Name of this Strategy Adapter
    string public name;

    /// @notice Identifier of this Strategy Adapter
    string public id;

    /*//////////////////////////////////////////////////////////////////////////
                                     CONSTRUCTOR
    //////////////////////////////////////////////////////////////////////////*/
    
    /// @dev Reverts if `_asset` doesn't match `asset` on the Multistrategy.
    /// @param _multistrategy Address of the multistrategy this strategy will belongs to.
    /// @param _asset Address of the token used to deposit and withdraw on this strategy.
    constructor(address _multistrategy, address _asset, string memory _name, string memory _id) StrategyAdapterAdminable(msg.sender) {
        require(_asset == IERC4626(_multistrategy).asset(), Errors.AssetMismatch(IERC4626(_multistrategy).asset(), _asset));

        multistrategy = _multistrategy;
        asset = _asset;
        slippageLimit = 0;
        name = _name;
        id = _id;

        IERC20(asset).forceApprove(multistrategy, type(uint256).max);
    }

    /// @dev Reverts if called by any account other than the Multistrategy this strategy belongs to.
    modifier onlyMultistrategy() {
        require(msg.sender == multistrategy, Errors.CallerNotMultistrategy(msg.sender));
        _;
    }

    /*//////////////////////////////////////////////////////////////////////////
                        USER FACING CONSTANT FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @inheritdoc IStrategyAdapter
    function totalAssets() external view returns (uint256) {
        return _totalAssets();
    }

    /// @inheritdoc IStrategyAdapter
    function currentPnL() external view returns (uint256, uint256) {
        return _calculateGainAndLoss(_totalAssets());
    }

    /*//////////////////////////////////////////////////////////////////////////
                        USER FACING NON-CONSTANT FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @inheritdoc IStrategyAdapter
    function requestCredit() external onlyOwner whenNotPaused {
        uint256 credit = IMultistrategy(multistrategy).requestCredit();
        if(credit > 0) {
            _deposit();
        }
    }

    /// @inheritdoc IStrategyAdapter
    function setSlippageLimit(uint256 _slippageLimit) external onlyOwner {
        require(_slippageLimit <= MAX_SLIPPAGE, Errors.SlippageLimitExceeded(_slippageLimit));
        
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
    /// @dev Any surplus on the withdraw won't be sent to the multistrategy.
    /// It will be eventually reported back as gain when sendReport is called.
    function withdraw(uint256 _amount) external onlyMultistrategy whenNotPaused returns (uint256) {
        _tryWithdraw(_amount);
        uint256 withdrawn = Math.min(_amount, _liquidity());
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
        _revokeAllowances();
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

    /// @notice Calculates the gain and loss based on current assets.
    /// 
    /// This function performs the following actions:
    /// - Retrieves the total debt of the strategy from the multi-strategy contract.
    /// - Determines whether the current assets are greater than or equal to the total debt to calculate the gain.
    /// - If the current assets are less than the total debt, calculates the loss.
    /// 
    /// @param _currentAssets The current assets held by the strategy.
    /// @return gain The calculated gain.
    /// @return loss The calculated loss.
    function _calculateGainAndLoss(uint256 _currentAssets) internal view returns (uint256, uint256) {
        uint256 totalDebt = IMultistrategy(multistrategy).strategyTotalDebt(address(this));
        uint256 gain = 0;
        uint256 loss = 0;

        if(_currentAssets >= totalDebt) {
            gain = _currentAssets - totalDebt;
        } else {
            loss = totalDebt - _currentAssets;
        }

        return (gain, loss);
    }

    /// @notice Calculates the amount to be withdrawn from the strategy.
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
    function _calculateAmountToBeWithdrawn(uint256 _repayAmount, uint256 _strategyGain) internal view returns (uint256) {   
        uint256 exceedingDebt = IMultistrategy(multistrategy).debtExcess(address(this));
        if(exceedingDebt > 0 && _repayAmount > 0) {
            if(slippageLimit == MAX_SLIPPAGE) return _repayAmount + _strategyGain;
            return Math.min(_repayAmount, exceedingDebt) + _strategyGain;
        } 

        return _strategyGain;
    }

    /// @notice Calculates the adjusted gain and loss after accounting for slippage.
    /// 
    /// This function performs the following actions:
    /// - Calculates the slippage loss as the difference between the amount intended to be withdrawn and the actual amount withdrawn.
    /// - If there is no slippage loss, returns the original gain and loss.
    /// - If there is slippage loss:
    ///   - Deducts the slippage loss from the gain.
    ///   - If the slippage loss exceeds the gain, the remaining slippage loss is added to the loss.
    /// - Returns the adjusted gain and loss after accounting for slippage.
    /// 
    /// @param _gain The initial gain before slippage.
    /// @param _loss The initial loss before slippage.
    /// @param _currentBalance The current balance of asset in this contract.
    /// @param _toBeWithdrawn The amount intended to be withdrawn.
    /// @return The adjusted gain and loss after slippage.
    function _calculateGainAndLossAfterSlippage(
        uint256 _gain, 
        uint256 _loss, 
        uint256 _currentBalance, 
        uint256 _toBeWithdrawn
        ) internal pure returns (uint256, uint256) {

        uint256 slippageLoss = (_toBeWithdrawn > _currentBalance) ? _toBeWithdrawn - _currentBalance : 0;
        if(slippageLoss == 0) return (_gain, _loss);
        if(slippageLoss > _gain) {
            slippageLoss -= _gain;
            _gain = 0;
        } else {
            _gain -= slippageLoss;
            slippageLoss = 0;
        }

        _loss += slippageLoss;
        return (_gain, _loss);
    }

    /// @notice Returns the current balance of asset in this contract.
    function _liquidity() internal view returns (uint256) {
        return IERC20(asset).balanceOf(address(this));
    }

    /// @notice Returns the amount of `asset` the underlying strategy holds. In the case this strategy
    /// has swapped `asset` for another asset, it should return the most approximate value.
    /// @dev Child contract must implement the logic to calculate the amount of assets.
    function _totalAssets() internal virtual view returns (uint256) {}

    /*//////////////////////////////////////////////////////////////////////////
                            INTERNAL NON-CONSTANT FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Sends a report on the strategy's performance.
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

        _tryWithdraw(toBeWithdrawn);
        (gain, loss) = _calculateGainAndLossAfterSlippage(gain, loss, _liquidity(), toBeWithdrawn);
        uint256 availableForRepay = _liquidity() - gain;
        
        IMultistrategy(multistrategy).strategyReport(availableForRepay, gain, loss);
    }

    /// @notice Sends a report on the strategy's performance after the strategy has been panicked.
    /// 
    /// This function performs the following actions:
    /// - Retrieves the current balance of the asset held by the contract.
    /// - Calculates the gain and loss based on the current assets.
    /// - Ensures that the gain is not used to repay the debt.
    /// - Reports the available amount for repayment, the gain, and the loss to the multi-strategy.
    function _sendReportPanicked() internal {
        uint256 currentAssets = _liquidity();
        (uint256 gain, uint256 loss) = _calculateGainAndLoss(currentAssets);

        uint256 availableForRepay = currentAssets - gain;

        IMultistrategy(multistrategy).strategyReport(availableForRepay, gain, loss);
    }

    /// @notice Attempts to withdraw a specified amount from the strategy.
    /// 
    /// This function performs the following actions:
    /// - Calls the internal `_withdraw` function to withdraw the desired amount.
    /// - Checks the current balance of the contract after the withdrawal.
    /// - If the balance is less than the desired amount, it reverts with an insufficient balance error.
    /// 
    /// @param _amount The amount to withdraw from the strategy.
    function _tryWithdraw(uint256 _amount) internal {
        if(_amount == 0 || _amount <= _liquidity()) return;

        // Liquidity is considered as amount already withdrawn, this amount doesn't need
        // to be withdrawn.
        _withdraw(_amount - _liquidity());

        uint256 currentBalance = _liquidity();
        uint256 desiredBalance = _amount.mulDiv(MAX_SLIPPAGE - slippageLimit, MAX_SLIPPAGE);
        
        require(currentBalance >= desiredBalance, Errors.SlippageCheckFailed(desiredBalance, currentBalance));
    }

    /// @notice Deposits the entire balance of `asset` this contract holds into the underlying strategy. 
    /// @dev Child contract must implement the logic that will put the funds to work.
    function _deposit() internal virtual {}

    /// @notice Withdraws the specified `_amount` of `asset` from the underlying strategy. 
    /// @dev Child contract must implement the logic that will withdraw the funds.
    /// @param _amount The amount of `asset` to withdraw.
    function _withdraw(uint256 _amount) internal virtual {}

    /// @notice Withdraws as much funds as possible from the underlying strategy.
    /// @dev Child contract must implement the logic to withdraw as much funds as possible.
    /// The withdraw process shouldn't have a slippage check, as it is in an emergency situation.
    /// 
    function _emergencyWithdraw() internal virtual {}

    /// @dev Grants allowance for `asset` to the contracts used by the strategy adapter.
    /// It should be overridden by derived contracts to specify the exact contracts and amounts for the allowances.
    function _giveAllowances() internal virtual {}

    /// @dev Revokes all previously granted allowances for `asset`.
    /// It should be overridden by derived contracts to specify the exact contracts from which allowances are revoked.
    function _revokeAllowances() internal virtual {}
}