// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.8.20 <0.9.0;

import { StrategyAdapter_Integration_Shared_Test } from "../../../shared/StrategyAdapter.t.sol";
import { IStrategyAdapterAdminable } from "interfaces/infra/multistrategy/IStrategyAdapterAdminable.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IStrategyAdapterMock, IPausable } from "../../../../shared/TestInterfaces.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";

contract Unpause_Integration_Concrete_Test is StrategyAdapter_Integration_Shared_Test {
    function test_RevertWhen_CallerNotOwner() external {
        swapCaller(users.bob);

        // Expect a revert
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, users.bob));
        strategy.unpause();
    }

    modifier whenCallerOwner() {
        _;
    }

    function test_RevertWhen_ContractNotPaused()
        external
        whenCallerOwner
    {
        // Expect a revert
        vm.expectRevert(abi.encodeWithSelector(Pausable.ExpectedPause.selector));
        strategy.unpause();
    }

    modifier whenContractPaused() {
        strategy.pause();
        _;
    }

    function test_Unpause()
        external
        whenCallerOwner
        whenContractPaused
    {
        // Expect the relevant event to be emitted
        vm.expectEmit({emitter: address(strategy)});
        emit Unpaused(users.owner);
        
        strategy.unpause();

        // Assert contract is not paused
        bool actualStrategyPaused = IPausable(address(strategy)).paused();
        bool expectedStrategyPaused = false;
        assertEq(actualStrategyPaused, expectedStrategyPaused, "pause");

        // Assert contract allowances are set
        address stakingContract = IStrategyAdapterMock(address(strategy)).stakingContract();
        uint256 actualBaseAssetAllowances = IERC20(strategy.baseAsset()).allowance(address(strategy), stakingContract);
        uint256 expectedBaseAssetAllowance = type(uint256).max;
        assertEq(actualBaseAssetAllowances, expectedBaseAssetAllowance, "unpause");
    }
}