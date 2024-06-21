// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.20 <0.9.0;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Errors } from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { MultistrategyHarness_Integration_Shared_Test } from "../../../shared/MultistrategyHarness.t.sol";
import { Errors } from "src/infra/libraries/Errors.sol";

contract IssueSharesForAmount_Integration_Concrete_Test is MultistrategyHarness_Integration_Shared_Test {
    uint256 amount;
    address receiver;
    function test_IssueSharesForAmount_ZeroAmount() external {
        amount = 0;
        receiver = users.bob;

        // Issue shares for amount = 0 to Bob
        multistrategyHarness.issueSharesForAmount(amount, receiver);

        // Assert 0 shares have been issued
        uint256 actualSharesIssued = IERC20(address(multistrategyHarness)).balanceOf(receiver);
        uint256 expectedSharesIssued = 0;
        assertEq(actualSharesIssued, expectedSharesIssued, "issueSharesForAmount zero amount");
    }

    modifier whenAmountGreaterThanZero() {
        _;
    }

    function test_RevertWhen_RecipientZeroAddres()
        external
        whenAmountGreaterThanZero
    {
        amount = 100 ether;
        receiver = address(0);

        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidReceiver.selector, receiver));
        multistrategyHarness.issueSharesForAmount(amount, receiver);
    }

    modifier whenRecipientNotZeroAddress() {
        _;
    }

    function test_IssueSharesForAmount_ZeroTotalSupply() 
        external
        whenAmountGreaterThanZero
        whenRecipientNotZeroAddress
    {
        amount = 100 ether;
        receiver = users.bob;

        // Issue shares for amount = 0 to Bob
        multistrategyHarness.issueSharesForAmount(amount, receiver);

        // Assert that the amount of shares issued is the same as amount
        uint256 actualSharesIssued = IERC20(address(multistrategyHarness)).balanceOf(receiver);
        uint256 expectedSharesIssued = amount;
        assertEq(actualSharesIssued, expectedSharesIssued, "issueSharesForAmount zero totalSupply");
    }

    modifier whenTotalSupplyGreaterThanZero() {
        triggerUserDeposit(users.alice, 1000 ether);
        _;
    }

    function test_IssueSharesForAmount()
        external
        whenAmountGreaterThanZero
        whenRecipientNotZeroAddress
        whenTotalSupplyGreaterThanZero
    {
        amount = 100 ether;
        receiver = users.bob;

        uint256 totalSupply = IERC20(address(multistrategyHarness)).totalSupply();
        uint256 freeFunds = multistrategyHarness.freeFunds();

        // Issue shares for amount = 0 to Bob
        multistrategyHarness.issueSharesForAmount(amount, receiver);

        // Assert the number of shares is correct
        uint256 actualSharesIssued = IERC20(address(multistrategyHarness)).balanceOf(receiver);
        uint256 expectedSharesIssued = Math.mulDiv(amount, totalSupply, freeFunds);
        assertEq(actualSharesIssued, expectedSharesIssued, "issueSharesForAmount zero totalSupply");
    }
}