// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.20 <0.9.0;

import { IERC4626, MultistrategyHarness_Integration_Shared_Test } from "../../../shared/MultistrategyHarness.t.sol";
import { StrategyAdapterMock } from "../../../../mocks/StrategyAdapterMock.sol";

contract Balance_Integration_Concrete_Test is MultistrategyHarness_Integration_Shared_Test {
    uint256 depositAmount = 1000 ether;

    function test_Balance_NoCredit() external {
        triggerUserDeposit(users.bob, depositAmount);

        uint256 actualBalance = multistrategyHarness.balance();
        uint256 expectedBalance = depositAmount;
        assertEq(actualBalance, expectedBalance, "balance");
    }

    modifier whenActiveCredit() {
        triggerUserDeposit(users.bob, depositAmount);
        StrategyAdapterMock strategy = deployMockStrategyAdapter(address(multistrategyHarness), IERC4626(address(multistrategyHarness)).asset());
        multistrategyHarness.addStrategy(address(strategy), 6_000, 0, 100_000 ether);
        strategy.requestCredit();
        _;
    }

    function test_Balance_ActiveCredit()
        external
        whenActiveCredit
    {
        uint256 actualBalance = multistrategyHarness.balance();
        uint256 expectedBalance = depositAmount - 600 ether;
        assertEq(actualBalance, expectedBalance, "balance");
    }
}