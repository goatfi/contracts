// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.20 <0.9.0;

import { Multistrategy } from "src/infra/multistrategy/Multistrategy.sol";
import { IMultistrategy } from "interfaces/infra/multistrategy/IMultistrategy.sol";

interface IMultistrategyHarness is IMultistrategy {
    function calculateLockedProfit() external view returns(uint256);
    function shareValue(uint256 _shares) external view returns(uint256);
    function sharesForAmount(uint256 _amount) external view returns(uint256);
    function freeFunds() external view returns(uint256);
}

/// @dev This contract exposes the internal functions of the multistrategy contract.
/// ONLY TO BE USED FOR TESTING
contract MultistrategyHarness is IMultistrategyHarness, Multistrategy {
    constructor(
        address _depositToken,
        address _manager,
        address _protocolFeeRecipient,
        string memory _name, 
        string memory _symbol
    ) 
        Multistrategy(
            _depositToken,
            _manager,
            _protocolFeeRecipient,
            _name,
            _symbol
        ) {}

    function calculateLockedProfit() external view returns(uint256) {
        return _calculateLockedProfit();
    }
    
    function shareValue(uint256 _shares) external view returns(uint256) {
        return _shareValue(_shares);
    }

    function sharesForAmount(uint256 _amount) external view returns(uint256) {
        return _sharesForAmount(_amount);
    }

    function freeFunds() external view returns(uint256) {
        return _freeFunds();
    }
}