// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.8.20 <0.9.0;

import { StrategyAdapter_Integration_Shared_Test } from "../../../shared/StrategyAdapter.t.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Errors } from "src/infra/libraries/Errors.sol";

contract SetSlippageLimit_Integration_Concrete_Test is StrategyAdapter_Integration_Shared_Test {
    function test_RevertWhen_CallerNotOwner() external {
        // Change caller to bob
        swapCaller(users.bob);

        // Set the slippage limit to 1%
        uint256 slippageLimit = 100;

        // Expect it to revert
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, users.bob));
        strategy.setSlippageLimit(slippageLimit);
    }

    modifier whenCallerIsOwner() {
        _;
    }

    function test_RevertWhen_SlippageLimitGreaterThanMaxSlippage()
        external
        whenCallerIsOwner
    {   
        // Set the slippage limit to 200%
        uint256 slippageLimit = 20_000;
        // Expect it to revert
        vm.expectRevert(abi.encodeWithSelector(Errors.SlippageLimitExceeded.selector, slippageLimit));
        strategy.setSlippageLimit(slippageLimit);
    }

    modifier whenSlippageLimitIsLowerThanMaxSlippage() {
        _;
    }

    function test_SetSlippageLimit_ZeroAmount() 
        external
        whenCallerIsOwner
        whenSlippageLimitIsLowerThanMaxSlippage
    {
        // Set the slippage limit to 0%
        uint256 slippageLimit = 0;
        
        vm.expectEmit({emitter: address(strategy)});
        emit SlippageLimitSet(slippageLimit);
        
        strategy.setSlippageLimit(slippageLimit);

        uint256 actualSlippageLimit = strategy.slippageLimit();
        uint256 expectedSlippageLimit = slippageLimit;
        assertEq(actualSlippageLimit, expectedSlippageLimit, "setSlippageLimit, zero amount");
    }

    function test_SetSlippageLimit_SameAmount() 
        external
        whenCallerIsOwner
        whenSlippageLimitIsLowerThanMaxSlippage
    {
        // Set the slippage limit to 1%
        uint256 slippageLimit = 100;

        // Set the slippage limit once, so we can test that we can set it again to
        // the same amount
        strategy.setSlippageLimit(slippageLimit);
        
        vm.expectEmit({emitter: address(strategy)});
        emit SlippageLimitSet(slippageLimit);
        
        strategy.setSlippageLimit(slippageLimit);

        uint256 actualSlippageLimit = strategy.slippageLimit();
        uint256 expectedSlippageLimit = slippageLimit;
        assertEq(actualSlippageLimit, expectedSlippageLimit, "setSlippageLimit, same amount");
    }

    function test_SetSlippageLimit_DifferentAmount() 
        external
        whenCallerIsOwner
        whenSlippageLimitIsLowerThanMaxSlippage
    {
        // Set the slippage limit to 0.1%
        uint256 slippageLimit = 10;
        
        vm.expectEmit({emitter: address(strategy)});
        emit SlippageLimitSet(slippageLimit);
        
        strategy.setSlippageLimit(slippageLimit);

        uint256 actualSlippageLimit = strategy.slippageLimit();
        uint256 expectedSlippageLimit = slippageLimit;
        assertEq(actualSlippageLimit, expectedSlippageLimit, "setSlippageLimit, different amount");
    }
}