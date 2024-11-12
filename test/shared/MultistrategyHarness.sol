// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.20 <0.9.0;

import { Multistrategy } from "src/infra/multistrategy/Multistrategy.sol";
import { IMultistrategy } from "interfaces/infra/multistrategy/IMultistrategy.sol";

interface IMultistrategyHarness is IMultistrategy {
    function liquidity() external view returns(uint256);
    function reportLoss(address _strategy, uint256 _loss) external;
}

/// @dev This contract exposes the internal functions of the multistrategy contract.
/// ONLY TO BE USED FOR TESTING
contract MultistrategyHarness is IMultistrategyHarness, Multistrategy {
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

    function liquidity() external view returns(uint256) {
        return _liquidity();
    }

    function reportLoss(address _strategy, uint256 _loss) external {
        _reportLoss(_strategy, _loss);
    }
}