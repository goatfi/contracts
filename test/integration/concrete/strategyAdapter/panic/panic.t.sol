// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.8.20 <0.9.0;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { StrategyAdapter_Integration_Shared_Test } from "../../../shared/StrategyAdapter.t.sol";
import { IStrategyAdapterAdminable } from "interfaces/infra/multistrategy/IStrategyAdapterAdminable.sol";
import { IStrategyAdapterMock, IPausable } from "../../../../shared/TestInterfaces.sol";
import { Errors } from "src/infra/libraries/Errors.sol";

contract Panic_Integration_Concrete_Test is StrategyAdapter_Integration_Shared_Test {
    function test_RevertWhen_CallerNotGuardian() external {
        swapCaller(users.bob);

        vm.expectRevert(abi.encodeWithSelector(Errors.CallerNotGuardian.selector, users.bob));
        strategy.panic();
    }

    modifier whenCallerGuardian() {
        IStrategyAdapterAdminable(address(strategy)).enableGuardian(users.guardian);
        swapCaller(users.guardian);
        _;
    }

    function test_Panic() external whenCallerGuardian {
        strategy.panic();

        // Assert emergencyWithdraw has been performed
        uint256 actualStakingBalance = IStrategyAdapterMock(address(strategy)).stakingBalance();
        uint256 expectedStakingBalance = 0;
        assertEq(actualStakingBalance, expectedStakingBalance, "panic, staking balance");

        // Assert allowance to the staking contract has been revoked
        address stakingContract = IStrategyAdapterMock(address(strategy)).stakingContract();
        uint256 actualStakingAllowance = IERC20(strategy.asset()).allowance(address(strategy), stakingContract);
        uint256 expectedStakingAllowance = 0;
        assertEq(actualStakingAllowance, expectedStakingAllowance, "panic, staking allowance");

        // Assert the contract has been paused
        bool actualContractPaused = IPausable(address(strategy)).paused();
        bool expectedContractPaused = true;
        assertEq(actualContractPaused, expectedContractPaused, "panic, contract paused");
    }
}