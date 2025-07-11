// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.20 <0.9.0;

import { Multistrategy } from "src/infra/multistrategy/Multistrategy.sol";
import { IMultistrategy } from "interfaces/infra/multistrategy/IMultistrategy.sol";

/// @dev This contract exposes the internal functions of the multistrategy contract.
/// ONLY TO BE USED FOR TESTING
contract MultistrategyHarness is Multistrategy {
    constructor(
        address _asset,
        address _manager,
        address _protocolFeeRecipient,
        string memory _name, 
        string memory _symbol
    ) 
        Multistrategy(
            _asset,
            _manager,
            _protocolFeeRecipient,
            _name,
            _symbol
        ) {}

    function calculateLockedProfit() external view returns(uint256) {
        return _calculateLockedProfit();
    }

    function balance() external view returns(uint256) {
        return _balance();
    }

    function freeFunds() external view returns(uint256) {
        return _freeFunds();
    }

    function reportLoss(address _strategy, uint256 _loss) external {
        _reportLoss(_strategy, _loss);
    }

    function profitUnlockTime() external pure returns (uint256) {
        return PROFIT_UNLOCK_TIME;
    }
}