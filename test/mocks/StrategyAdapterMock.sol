// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { StrategyAdapter } from "src/abstracts/StrategyAdapter.sol";

contract StrategyAdapterMock is StrategyAdapter {
    constructor(
        address _multistrategy,
        address _depositToken
    ) 
        StrategyAdapter(_multistrategy, _depositToken) 
    {
        
    }
}