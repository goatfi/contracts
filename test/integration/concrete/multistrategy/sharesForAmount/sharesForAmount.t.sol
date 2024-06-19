// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.20 <0.9.0;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { MultistrategyHarness_Integration_Shared_Test } from "../../../shared/MultistrategyHarness.t.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

contract SharesForAmount_Integration_Concrete_Test is MultistrategyHarness_Integration_Shared_Test {
    uint256 amount = 1000 ether;

    function test_SharesForAmount_ZeroAmount() external {
        //Assert that shares for amount is zero when the amount of shares is zero
        uint256 actualSharesForAmount = multistrategyHarness.sharesForAmount(0);
        uint256 expectedSharesForAmount = 0;
        assertEq(actualSharesForAmount, expectedSharesForAmount, "sharesForAmount");
    }

    modifier whenAmountNotZero() {
        _;
    }

    function test_SharesForAmount_ZeroFreeFunds() 
        external 
        whenAmountNotZero
    {
        //Assert that shares for amount is zero when the amount of shares is zero
        uint256 actualSharesForAmount = multistrategyHarness.sharesForAmount(amount);
        uint256 expectedSharesForAmount = 0;
        assertEq(actualSharesForAmount, expectedSharesForAmount, "sharesForAmount");
    }

    modifier whenFreeFundsNotZero() {
        triggerUserDeposit(users.bob, 1000 ether);
        _;
    }

    function test_SharesForAmount()
        external
        whenAmountNotZero
        whenFreeFundsNotZero
    {
        uint256 freeFunds = multistrategyHarness.freeFunds();
        uint256 totalSupply = IERC20(address(multistrategyHarness)).totalSupply();

        //Assert that shares for amount is the amount multiplied by totalSupply and divided by freeFunds
        uint256 actualSharesForAmount = multistrategyHarness.sharesForAmount(amount);
        uint256 expectedSharesForAmount = Math.mulDiv(amount, totalSupply, freeFunds);
        assertEq(actualSharesForAmount, expectedSharesForAmount, "sharesForAmount");
    }
}