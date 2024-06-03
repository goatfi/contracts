// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.20 <0.9.0;

import { Multistrategy_Unit_Shared_Test } from "../../../shared/Multistrategy.t.sol";
import { Errors } from "src/infra/libraries/Errors.sol";

contract SetProtocolFeeRecipient_Unit_Concrete_Test is Multistrategy_Unit_Shared_Test {
    function test_RevertWhen_CallerNotManager() external {

    }

    modifier whenCallerIsManager() {
        swapCaller(users.keeper);
        _;
    }
}