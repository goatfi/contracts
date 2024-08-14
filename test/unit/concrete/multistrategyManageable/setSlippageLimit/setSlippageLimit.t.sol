// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.20 <0.9.0;

import { Multistrategy_Unit_Shared_Test} from "../../../shared/Multistrategy.t.sol";
import { Errors } from "src/infra/libraries/Errors.sol";

contract SetSlippageLimit_Unit_Concrete_Test is Multistrategy_Unit_Shared_Test {
    uint256 slippageLimit;
    function test_RevertWhen_CallerNotManager() external {
        // Change caller to bob
        swapCaller(users.bob);
        
        // Expect a revert
        vm.expectRevert(abi.encodeWithSelector(Errors.CallerNotManager.selector, users.bob));
        multistrategy.setSlippageLimit(slippageLimit);
    }

    modifier whenCallerIsManager() {
        swapCaller(users.keeper);
        _;
    }

    function test_SetSlippageLimit_SameSlippageLimit()
        external
        whenCallerIsManager
    {
        slippageLimit = 100;
        
        // Expect the relevant event to be emitted.
        vm.expectEmit({ emitter: address(multistrategy) });
        emit SlippageLimitSet(slippageLimit);

        multistrategy.setSlippageLimit(slippageLimit);

        // Assert slippage limit has been set
        uint256 actualSlippageLimit = multistrategy.slippageLimit();
        uint256 expectedSlippageLimit = slippageLimit;
        assertEq(actualSlippageLimit, expectedSlippageLimit, "slippage limit");
    }

    function test_SetSlippageLimit_ZeroSlippageLimit()
        external
        whenCallerIsManager
    {
        slippageLimit = 0;

        // Expect the relevant event to be emitted.
        vm.expectEmit({ emitter: address(multistrategy) });
        emit SlippageLimitSet(slippageLimit);

        multistrategy.setSlippageLimit(slippageLimit);

        // Assert slippage limit has been set
        uint256 actualSlippageLimit = multistrategy.slippageLimit();
        uint256 expectedSlippageLimit = slippageLimit;
        assertEq(actualSlippageLimit, expectedSlippageLimit, "slippage limit");
    }

    modifier whenNotZeroSlippageLimit() {
        _;
    }

    function test_SetSlippageLimit_NewSlippageLimit()
        external
        whenCallerIsManager
        whenNotZeroSlippageLimit
    {
        slippageLimit = 500;

        // Expect the relevant event to be emitted.
        vm.expectEmit({ emitter: address(multistrategy) });
        emit SlippageLimitSet(slippageLimit);

        multistrategy.setSlippageLimit(slippageLimit);

        // Assert slippage limit has been set
        uint256 actualSlippageLimit = multistrategy.slippageLimit();
        uint256 expectedSlippageLimit = slippageLimit;
        assertEq(actualSlippageLimit, expectedSlippageLimit, "slippage limit");
    }
}