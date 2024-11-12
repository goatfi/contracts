// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.8.20 <0.9.0;

import { IERC4626, StrategyAdapter_Integration_Shared_Test } from "../../../shared/StrategyAdapter.t.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import { IStrategyAdapterMock } from "../../../../shared/TestInterfaces.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";

contract RequestCredit_Integration_Concrete_Test is StrategyAdapter_Integration_Shared_Test {
    function test_RevertWhen_CallerNotOwner() external {
        // Change caller to bob
        swapCaller(users.bob);

        // Expect it to revert
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, users.bob));
        strategy.requestCredit();
    }

    modifier whenCallerIsOwner() {
        _;
    }

    function test_RevertWhen_ContractIsPaused()
        external
        whenCallerIsOwner
    {
        strategy.pause();
        
        // Expect it to revert
        vm.expectRevert(abi.encodeWithSelector(Pausable.EnforcedPause.selector));
        strategy.requestCredit();
    }

    modifier whenNotPaused() {
        _;
    }

    function test_RequestCredit_NoCredit()
        external
        whenCallerIsOwner
        whenNotPaused
    {
        multistrategy.addStrategy(address(strategy), 10_000, 0, 100_000 * 10 ** decimals);
        uint256 previousTotalAssets = strategy.totalAssets();

        strategy.requestCredit();

        // Assert totalAssets didn't increase
        uint256 actualTotalAssets = strategy.totalAssets();
        uint256 expectedTotalAssets = previousTotalAssets;
        assertEq(actualTotalAssets, expectedTotalAssets, "requestCredit, totalAssets");
    }

    function test_RequestCredit()
        external
        whenCallerIsOwner
        whenNotPaused
    {
        triggerUserDeposit(users.bob, 1000 * 10 ** decimals);
        multistrategy.addStrategy(address(strategy), 10_000, 0, 100_000 * 10 ** decimals);
        
        strategy.requestCredit();

        // Assert totalAssets has increased
        uint256 actualTotalAssets = strategy.totalAssets();
        uint256 expectedTotalAssets = 1000 * 10 ** decimals;
        assertEq(actualTotalAssets, expectedTotalAssets, "requestCredit, totalAssets");

        // Assert the credit has been deposited into the underlying strategy
        uint256 actualStrategyAssets = IStrategyAdapterMock(address(strategy)).stakingBalance();
        uint256 expectedStrategyAssets = 1000 * 10 ** decimals;
        assertEq(actualStrategyAssets, expectedStrategyAssets, "requestCredit, strategy assets");
    }
}