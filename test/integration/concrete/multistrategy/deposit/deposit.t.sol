// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.20 <0.9.0;

import { IERC4626, Multistrategy_Integration_Shared_Test} from "../../../shared/Multistrategy.t.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import {Errors} from "src/infra/libraries/Errors.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";

contract Deposit_Integration_Concrete_Test is
    Multistrategy_Integration_Shared_Test
{
    uint256 amount;
    address recipient;
    uint8 decimals;

    function setUp() public virtual override {
        Multistrategy_Integration_Shared_Test.setUp();
        decimals = IERC20Metadata(IERC4626(address(multistrategy)).asset()).decimals();
    }

    function test_RevertWhen_ContractIsPaused() external {
        amount = 150_000 * 10 ** decimals;
        recipient = users.bob;

        // Pause the multistrategy
        multistrategy.pause();

        // Expect a revert
        vm.expectRevert(abi.encodeWithSelector(Pausable.EnforcedPause.selector));
        IERC4626(address(multistrategy)).deposit(amount, recipient);
    }

    modifier whenContractNotPaused() {
        _;
    }

    function test_RevertWhen_Retired() 
        external 
        whenContractNotPaused
    {
        amount = 150_000 * 10 ** decimals;
        recipient = users.bob;

        multistrategy.retire();

        // Expect a revert
        vm.expectRevert(abi.encodeWithSelector(Errors.Retired.selector));
        IERC4626(address(multistrategy)).deposit(amount, recipient);
    }

    modifier whenNotRetired() {
        _;
    }

    modifier whenRecipientNotZeroAddress() {
        _;
    }

    /// @dev Deposit limit is 100K tokens
    function test_RevertWhen_AssetsAboveMaxDeposit()
        external
        whenContractNotPaused
        whenNotRetired
        whenRecipientNotZeroAddress
        whenRecipientNotContractAddress
        whenAmountIsGreaterThanZero
    {
        amount = 150_000 * 10 ** decimals;
        recipient = users.bob;

        // Expect a revert
        vm.expectRevert(abi.encodeWithSelector(Errors.ERC4626ExceededMaxDeposit.selector, recipient, amount, 100_000 * 10 ** decimals));
        IERC4626(address(multistrategy)).deposit(amount, recipient);
    }

    /// @dev Approve the tokens to be able to deposit
    modifier whenDepositLimitRespected() {
        triggerApprove(users.bob, address(multistrategy), 1000 * 10 ** decimals);
        _;
    }

    function test_RevertWhen_RecipientIsZeroAddress() 
        external
        whenContractNotPaused
        whenNotRetired
        whenDepositLimitRespected 
    {
        amount = 0;
        recipient = address(0);

        // Expect a revert
        vm.expectRevert(
            abi.encodeWithSelector(Errors.InvalidAddress.selector, address(0))
        );
        IERC4626(address(multistrategy)).deposit(amount, recipient);
    }

    function test_RevertWhen_RecipientIsContractAddress()
        external
        whenContractNotPaused
        whenNotRetired
        whenRecipientNotZeroAddress
        whenDepositLimitRespected
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
        IERC4626(address(multistrategy)).deposit(amount, recipient);
    }

    modifier whenRecipientNotContractAddress() {
        _;
    }

    function test_RevertWhen_AmountIsZero()
        external
        whenContractNotPaused
        whenNotRetired
        whenRecipientNotZeroAddress
        whenDepositLimitRespected
        whenRecipientNotContractAddress
    {
        amount = 0;
        recipient = users.bob;

        // Expect a revert
        vm.expectRevert(abi.encodeWithSelector(Errors.ZeroAmount.selector, 0));
        IERC4626(address(multistrategy)).deposit(amount, recipient);
    }

    modifier whenAmountIsGreaterThanZero() {
        _;
    }

    function test_RevertWhen_CallerHasInsufficientBalance()
        external
        whenContractNotPaused
        whenNotRetired
        whenRecipientNotZeroAddress
        whenDepositLimitRespected
        whenRecipientNotContractAddress
        whenAmountIsGreaterThanZero
    {
        amount = 1000 * 10 ** decimals;
        recipient = users.bob;

        swapCaller(users.bob);
        // Expect a revert
        vm.expectRevert();
        IERC4626(address(multistrategy)).deposit(amount, recipient);
    }

    modifier whenCallerHasEnoughBalance() {
        mintAsset(users.bob, 1000 * 10 ** decimals);
        _;
    }

    function test_Deposit()
        external
        whenContractNotPaused
        whenNotRetired
        whenRecipientNotZeroAddress
        whenDepositLimitRespected
        whenRecipientNotContractAddress
        whenAmountIsGreaterThanZero
        whenCallerHasEnoughBalance
    {
        amount = 1000 * 10 ** decimals;
        recipient = users.bob;
        uint256 shares = IERC4626(address(multistrategy)).previewDeposit(amount);

        vm.expectEmit({emitter: address(multistrategy)});
        emit Deposit(users.bob, recipient, amount, shares);

        swapCaller(users.bob);
        IERC4626(address(multistrategy)).deposit(amount, recipient);

        // Assert correct amount of shares have been minted to recipient
        uint256 actualMintedShares = IERC20(address(multistrategy)).balanceOf(recipient);
        uint256 expectedMintedShares = shares;
        assertEq(actualMintedShares, expectedMintedShares, "deposit");

        // Assert the assets have been deducted from the caller
        uint256 actualUserBalance = IERC20(address(asset)).balanceOf(recipient);
        uint256 expectedUserBalance = 0;
        assertEq(actualUserBalance, expectedUserBalance, "deposit user balance");

        // Assert the assets have been transferred to the multistrategy
        uint256 actualMultistrategyBalance = IERC20(address(asset)).balanceOf(address(multistrategy));
        uint256 expectedMultistrategyBalance = amount;
        assertEq(actualMultistrategyBalance, expectedMultistrategyBalance, "deposit multistrategy balance");
    }
}