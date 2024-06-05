// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { StrategyWrapper } from "src/abstracts/StrategyWrapper.sol";

contract StrategyWrapperMock is StrategyWrapper {
    constructor(
        address _multistrategy,
        address _depositToken
    ) 
        StrategyWrapper(_multistrategy, _depositToken) 
    {
        
    }
}