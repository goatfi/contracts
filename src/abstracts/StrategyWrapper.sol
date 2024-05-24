// SPDX-License-Identifier: MIT

pragma solidity >=0.8.20 <= 0.9.0;

import { IERC20, SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IStrategyWrapper } from "interfaces/infra/multistrategy/IStrategyWrapper.sol";
import { IMultistrategyManageable } from "interfaces/infra/multistrategy/IMultistrategyManageable.sol";
import { Errors } from "src/infra/libraries/Errors.sol";

abstract contract StrategyWrapper is IStrategyWrapper {
    using SafeERC20 for IERC20;

    /// @inheritdoc IStrategyWrapper
    address public multistrategy;

    /// @inheritdoc IStrategyWrapper
    address public depositToken;

    /// @dev Reverts if `_depositToken` doesn't match `depositToken` on the Multistrategy.
    /// @param _multistrategy Address of the multistrategy this strategy will belongs to.
    /// @param _depositToken Address of the token used to deposit and withdraw on this strategy.
    constructor(address _multistrategy, address _depositToken) {
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
        if(msg.sender != multistrategy) revert Errors.CallerNotMultistrategy(msg.sender);
        _;
    }

    /// @inheritdoc IStrategyWrapper
    function deposit(uint256 _amount) external onlyMultistrat {
        IERC20(depositToken).safeTransferFrom(multistrategy, address(this), _amount);
        _deposit();
    }

    /// @inheritdoc IStrategyWrapper
    function withdraw(uint256 _amount) external onlyMultistrat {
        _withdraw(_amount);
        IERC20(depositToken).safeTransfer(multistrategy, _amount);
    }

    /// @inheritdoc IStrategyWrapper
    function totalAssets() external view returns(uint256) {
        return _totalAssets();
    }

    function _deposit() internal virtual {}
    function _withdraw(uint256 _amount) internal virtual {}
    function _totalAssets() internal virtual view returns(uint256) {}
}