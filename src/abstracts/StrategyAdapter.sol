// SPDX-License-Identifier: GNU AGPLv3

pragma solidity >=0.8.20 <= 0.9.0;

import { IERC20, SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { IStrategyAdapter } from "interfaces/infra/multistrategy/IStrategyAdapter.sol";
import { IMultistrategy } from "interfaces/infra/multistrategy/IMultistrategy.sol";
import { IMultistrategyManageable } from "interfaces/infra/multistrategy/IMultistrategyManageable.sol";
import { Errors } from "src/infra/libraries/Errors.sol";

abstract contract StrategyAdapter is IStrategyAdapter, Ownable {
    using SafeERC20 for IERC20;

    /// @dev 100% in BPS, setting the slippage to 100% means no slippage protection.
    uint256 constant MAX_SLIPPAGE = 10_000;

    /// @inheritdoc IStrategyAdapter
    address public multistrategy;

    /// @inheritdoc IStrategyAdapter
    address public depositToken;

    /// @inheritdoc IStrategyAdapter
    uint256 public slippageLimit;
    
    /// @dev Reverts if `_depositToken` doesn't match `depositToken` on the Multistrategy.
    /// @param _multistrategy Address of the multistrategy this strategy will belongs to.
    /// @param _depositToken Address of the token used to deposit and withdraw on this strategy.
    constructor(address _multistrategy, address _depositToken) Ownable(msg.sender) {
        if(IMultistrategyManageable(_multistrategy).depositToken() != _depositToken) {
            revert Errors.DepositTokenMissmatch({
                multDepositToken: IMultistrategyManageable(_multistrategy).depositToken(),
                stratDepositToken: _depositToken
            });
        }

        multistrategy = _multistrategy;
        depositToken = _depositToken;
        slippageLimit = 0;

        IERC20(depositToken).safeIncreaseAllowance(multistrategy, type(uint256).max);
    }

    /// @dev Reverts if called by any account other than the Multistrategy this strategy belongs to.
    modifier onlyMultistrat() {
        if(msg.sender != multistrategy) {
            revert Errors.CallerNotMultistrategy(msg.sender);
        }
        _;
    }

    /// @inheritdoc IStrategyAdapter
    function requestCredit() external onlyOwner {
        IMultistrategy(multistrategy).requestCredit();
        _deposit();
    }

    /// @inheritdoc IStrategyAdapter
    function setSlippageLimit(uint256 _slippageLimit) external onlyOwner {
        slippageLimit = _slippageLimit;
    }
    
    /// @inheritdoc IStrategyAdapter
    function sendReport(uint256 _repayAmount) external onlyOwner {
        _sendReport(_repayAmount);
    }

    /// @inheritdoc IStrategyAdapter
    function sendReport() external onlyMultistrat {
        _sendReport(0);
    }

    /// @inheritdoc IStrategyAdapter
    function withdraw(uint256 _amount) external onlyMultistrat {
        _tryWithdraw(_amount);

        IERC20(depositToken).safeTransfer(multistrategy, _amount);
    }

    /// @notice Internal function to send a report on the strategy's performance.
    /// 
    /// This function performs the following actions:
    /// - Calculates the current assets and total debt of the strategy.
    /// - Determines whether the strategy has made a gain or a loss.
    /// - Attempts to withdraw the repayment amount plus any gain.
    /// - Ensures that the gain is not used to repay the debt.
    /// - Reports the available amount for repayment, the gain, and the loss to the multi-strategy.
    /// 
    /// @param _repayAmount The amount to be repaid to the multi-strategy.
    function _sendReport(uint256 _repayAmount) internal {
        uint256 currentAssets = _totalAssets();
        uint256 totalDebt = IMultistrategy(multistrategy).strategyTotalDebt(address(this));
        uint256 gain = 0;
        uint256 loss = 0;

        // Check if the strategy has made a gain
        if(currentAssets >= totalDebt) {
            gain = currentAssets - totalDebt;
        } else {
            loss = totalDebt - currentAssets;
        }

        // Withdraw the desired amount to repay plus the gain.
        _tryWithdraw(_repayAmount + gain);

        // Gain shouldn't be used to repay the debt
        uint256 availableForRepay = IERC20(depositToken).balanceOf(address(this)) - gain;

        //Report to the strategy
        IMultistrategy(multistrategy).strategyReport(availableForRepay, gain, loss);
    }

    /// @inheritdoc IStrategyAdapter
    function totalAssets() external view returns(uint256) {
        return _totalAssets();
    }

    /// @notice Internal function to attempt to withdraw a specified amount from the strategy.
    /// 
    /// This function performs the following actions:
    /// - Calls the internal `_withdraw` function to withdraw the desired amount.
    /// - Checks the current balance of the contract after the withdrawal.
    /// - If the balance is less than the desired amount, it reverts with an insufficient balance error.
    /// 
    /// @param _amount The amount to withdraw from the strategy.
    function _tryWithdraw(uint256 _amount) internal {
        // Withdraw the desired amount
        _withdraw(_amount);

        // Check that the strategy was able to withdraw the desired amount
        uint256 currentBalance = IERC20(depositToken).balanceOf(address(this));
        uint256 desiredBalance = Math.mulDiv(_amount, MAX_SLIPPAGE - slippageLimit, MAX_SLIPPAGE);
        if(currentBalance < desiredBalance) {
            // If it hasn't been able, revert.
            revert Errors.SlippageCheckFailed(desiredBalance, currentBalance);
        }
    }

    /// @dev Must implement the logic that will put the funds to work.
    function _deposit() internal virtual {}

    /// @dev Amount is `depositToken` amount. So if we call `withdraw(100 ether)` it should
    /// withdraw 100 `depositToken`. Keep in mind that if a vault is in loss, we'll reach a point
    /// where withdrawing is no longer possible.
    ///
    /// This function is used in `withdraw` and `sendReport` functions. These functions will revert
    /// if `_withdraw` hasn't been able to withdraw `_amount`.
    function _withdraw(uint256 _amount) internal virtual {}

    /// @dev Must return the amount of `depositToken` this strategy holds. In the case this strategy
    /// has swapped `depositToken` for another token, it should return the most approximate value.
    function _totalAssets() internal virtual view returns(uint256) {}
}