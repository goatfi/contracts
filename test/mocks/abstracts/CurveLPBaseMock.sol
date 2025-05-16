// SPDX-License-Identifier: GNU AGPLv3
pragma solidity 0.8.27;

import { CurveLPBase } from "src/abstracts/CurveLPBase.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

contract CurveLPBaseMock is CurveLPBase {
    constructor(address _curveLiquidityPool, address _curveSlippageUtility) 
        CurveLPBase(_curveLiquidityPool, _curveSlippageUtility)
        Ownable(msg.sender) {}
}