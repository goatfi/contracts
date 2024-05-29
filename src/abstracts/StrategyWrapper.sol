// SPDX-License-Identifier: GNU AGPLv3

pragma solidity >=0.8.20 <= 0.9.0;

import { IERC20, SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IStrategyWrapper } from "interfaces/infra/multistrategy/IStrategyWrapper.sol";
import { IMultistrategy } from "interfaces/infra/multistrategy/IMultistrategy.sol";
import { IMultistrategyManageable } from "interfaces/infra/multistrategy/IMultistrategyManageable.sol";
import { Errors } from "src/infra/libraries/Errors.sol";

abstract contract StrategyWrapper is IStrategyWrapper, Ownable {
    using SafeERC20 for IERC20;

    /// @inheritdoc IStrategyWrapper
    address public multistrategy;

    /// @inheritdoc IStrategyWrapper
    address public depositToken;
    
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
    }

    /// @dev Reverts if called by any account other than the Multistrategy this strategy belongs to.
    modifier onlyMultistrat() {
        if(msg.sender != multistrategy) {
            revert Errors.CallerNotMultistrategy(msg.sender);
        }
        _;
    }

    /// @inheritdoc IStrategyWrapper
    function requestCredit() external onlyOwner {
        IMultistrategy(multistrategy).requestCredit();
        _deposit();
    }

    /// @inheritdoc IStrategyWrapper
    function sendReport(uint256 _repayAmount) external onlyOwner {
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

    /// @inheritdoc IStrategyWrapper
    function withdraw(uint256 _amount) external onlyMultistrat {
        _tryWithdraw(_amount);

        IERC20(depositToken).safeTransfer(multistrategy, _amount);
    }

    /// @inheritdoc IStrategyWrapper
    function totalAssets() external view returns(uint256) {
        return _totalAssets();
    }

    /// @dev Tries to withdraw `_amount`. If `_withdraw` hasn't been able to withdraw
    /// the desired amount, it reverts.
    /// Is up to the `_withdraw` implementation
    function _tryWithdraw(uint256 _amount) internal {
        // Withdraw the desired amount
        _withdraw(_amount);

        // Check that the strategy was able to withdraw the desired amount
        uint256 currentBalance = IERC20(depositToken).balanceOf(address(this));
        if(currentBalance < _amount) {
            // If it hasn't been able, revert.
            revert Errors.InsufficientBalance(currentBalance, _amount);
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