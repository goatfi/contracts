// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.20 <0.9.0;

import {Multistrategy_Integration_Shared_Test} from "../../../shared/Multistrategy.t.sol";
import {IStrategyAdapter} from "interfaces/infra/multistrategy/IStrategyAdapter.sol";
import {Errors} from "src/infra/libraries/Errors.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";

contract Deposit_Integration_Concrete_Test is
    Multistrategy_Integration_Shared_Test
{
    uint256 amount;
    address recipient;

    function test_RevertWhen_ContractIsPaused() external {
        // Pause the multistrategy
        multistrategy.pause();

        // Expect a revert
        vm.expectRevert(abi.encodeWithSelector(Pausable.EnforcedPause.selector));
        multistrategy.requestCredit();
    }

    modifier whenContractNotPaused() {
        _;
    }

    function test_RevertWhen_RecipientIsZeroAddress() external {
        amount = 0;
        recipient = address(0);

        // Expect a revert
        vm.expectRevert(
            abi.encodeWithSelector(Errors.InvalidAddress.selector, address(0))
        );
        multistrategy.deposit(amount, recipient);
    }

    modifier whenRecipientNotZeroAddress() {
        _;
    }

    function test_RevertWhen_RecipientIsContractAddress()
        external
        whenRecipientNotZeroAddress
    {
        amount = 0;
        recipient = address(multistrategy);

        // Expect a revert
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.InvalidAddress.selector,
                address(multistrategy)
            )
        );
        multistrategy.deposit(amount, recipient);
    }

    modifier whenRecipientNotContractAddress() {
        _;
    }

    function test_RevertWhen_AmountIsZero()
        external
        whenRecipientNotZeroAddress
        whenRecipientNotContractAddress
    {
        amount = 0;
        recipient = users.bob;

        // Expect a revert
        vm.expectRevert(abi.encodeWithSelector(Errors.ZeroAmount.selector, 0));
        multistrategy.deposit(amount, recipient);
    }

    modifier whenAmountIsGreaterThanZero() {
        _;
    }

    /// @dev Deposit limit is 100K tokens
    function test_RevertWhen_AmountPlusTotalAssetsGreaterThanDepositLimit()
        external
        whenRecipientNotZeroAddress
        whenRecipientNotContractAddress
        whenAmountIsGreaterThanZero
    {
        amount = 150_000 ether;
        recipient = users.bob;

        // Expect a revert
        vm.expectRevert(abi.encodeWithSelector(Errors.DepositLimit.selector));
        multistrategy.deposit(amount, recipient);
    }

    /// @dev Approve the tokens to be able to deposit
    modifier whenDepositLimitRespected() {
        swapCaller(users.bob);
        dai.approve(address(multistrategy), 1000 ether);
        swapCaller(users.owner);
        _;
    }

    function test_RevertWhen_CallerHasInsufficientBalance()
        external
        whenRecipientNotZeroAddress
        whenRecipientNotContractAddress
        whenAmountIsGreaterThanZero
        whenDepositLimitRespected
    {
        amount = 1000 ether;
        recipient = users.bob;

        // Expect a revert
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Errors.ERC20InsufficientBalance.selector,
                users.bob,
                0,
                1000 ether
            )
        );
        swapCaller(users.bob);
        multistrategy.deposit(amount, recipient);
    }

    modifier whenCallerHasEnoughBalance() {
        dai.mint(users.bob, 1000 ether);
        _;
    }

    function test_Deposit()
        external
        whenRecipientNotZeroAddress
        whenRecipientNotContractAddress
        whenAmountIsGreaterThanZero
        whenDepositLimitRespected
        whenCallerHasEnoughBalance
    {
        amount = 1000 ether;
        recipient = users.bob;

        vm.expectEmit({emitter: address(multistrategy)});
        emit Deposit(amount, recipient);

        swapCaller(users.bob);
        multistrategy.deposit(amount, recipient);

        // Assert correct amount of shares have been minted to recipient
        uint256 actualMintedShares = IERC20(address(multistrategy)).balanceOf(recipient);
        uint256 expectedMintedShares = amount;
        assertEq(actualMintedShares, expectedMintedShares, "deposit");

        // Assert the baseAssets have been deducted from the caller
        uint256 actualUserBalance = IERC20(address(dai)).balanceOf(recipient);
        uint256 expectedUserBalance = 0;
        assertEq(actualUserBalance, expectedUserBalance, "deposit user balance");

        // Assert the baseAssets have been transfered to the multistrategy
        uint256 actualMultistrategyBalance = IERC20(address(dai)).balanceOf(address(multistrategy));
        uint256 expectedMultistrategyBalance = amount;
        assertEq(actualMultistrategyBalance, expectedMultistrategyBalance, "deposit multistrategy balance");
    }
}