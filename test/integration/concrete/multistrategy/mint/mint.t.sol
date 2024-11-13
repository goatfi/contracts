// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.20 <0.9.0;

import { IERC4626, Multistrategy_Integration_Shared_Test} from "../../../shared/Multistrategy.t.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import {IStrategyAdapter} from "interfaces/infra/multistrategy/IStrategyAdapter.sol";
import {Errors} from "src/infra/libraries/Errors.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";

contract Mint_Integration_Concrete_Test is Multistrategy_Integration_Shared_Test {
    uint256 shares;
    uint8 decimals;
    address recipient;

    function setUp() public virtual override {
        Multistrategy_Integration_Shared_Test.setUp();
        decimals = IERC20Metadata(IERC4626(address(multistrategy)).asset()).decimals();
    }

    function test_RevertWhen_ContractIsPaused() external {
        shares = 150_000 * 10 ** decimals;
        recipient = users.bob;
        
        // Pause the multistrategy
        multistrategy.pause();

        // Expect a revert
        vm.expectRevert(abi.encodeWithSelector(Pausable.EnforcedPause.selector));
        IERC4626(address(multistrategy)).mint(shares, recipient);
    }

    modifier whenContractNotPaused() {
        _;
    }

    function test_RevertWhen_DepositIsPaused() 
        external 
        whenContractNotPaused
    {
        shares = 150_000 * 10 ** decimals;
        recipient = users.bob;

        //Pause Deposit
        multistrategy.pauseDeposit();

        // Expect a revert
        vm.expectRevert(abi.encodeWithSelector(Errors.DepositPaused.selector));
        IERC4626(address(multistrategy)).mint(shares, recipient);
    }

    modifier whenRecipientNotZeroAddress() {
        _;
    }

    modifier whenRecipientNotContractAddress() {
        _;
    }

    modifier whenAmountIsGreaterThanZero() {
        _;
    }


    /// @dev Deposit limit is 100K tokens
    function test_RevertWhen_AssetsAboveMaxMint()
        external
        whenRecipientNotZeroAddress
        whenRecipientNotContractAddress
        whenAmountIsGreaterThanZero
    {
        shares = 150_000 ether;
        recipient = users.bob;

        // Expect a revert
        vm.expectRevert(abi.encodeWithSelector(Errors.ERC4626ExceededMaxMint.selector, recipient, shares, 100_000 ether));
        IERC4626(address(multistrategy)).mint(shares, recipient);
    }

    /// @dev Approve the tokens to be able to deposit
    modifier whenDepositLimitRespected() {
        triggerApprove(users.bob, address(multistrategy), 1000 * 10 ** decimals);
        _;
    }

    function test_RevertWhen_RecipientIsZeroAddress() 
        external
        whenDepositLimitRespected 
    {
        shares = 0;
        recipient = address(0);

        // Expect a revert
        vm.expectRevert(
            abi.encodeWithSelector(Errors.InvalidAddress.selector, address(0))
        );
        IERC4626(address(multistrategy)).mint(shares, recipient);
    }

    function test_RevertWhen_RecipientIsContractAddress()
        external
        whenRecipientNotZeroAddress
        whenDepositLimitRespected
    {
        shares = 0;
        recipient = address(multistrategy);

        // Expect a revert
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.InvalidAddress.selector,
                address(multistrategy)
            )
        );
        IERC4626(address(multistrategy)).mint(shares, recipient);
    }

    function test_RevertWhen_AmountIsZero()
        external
        whenRecipientNotZeroAddress
        whenDepositLimitRespected
        whenRecipientNotContractAddress
    {
        shares = 0;
        recipient = users.bob;

        // Expect a revert
        vm.expectRevert(abi.encodeWithSelector(Errors.ZeroAmount.selector, 0));
        IERC4626(address(multistrategy)).mint(shares, recipient);
    }

    function test_RevertWhen_CallerHasInsufficientBalance()
        external
        whenRecipientNotZeroAddress
        whenDepositLimitRespected
        whenRecipientNotContractAddress
        whenAmountIsGreaterThanZero
    {
        shares = 1000 * 10 ** decimals;
        recipient = users.bob;

        swapCaller(users.bob);
        // Expect a revert
        vm.expectRevert();
        IERC4626(address(multistrategy)).mint(shares, recipient);
    }

    modifier whenCallerHasEnoughBalance() {
        mintAsset(users.bob, 1000 * 10 ** decimals);
        _;
    }

    function test_Mint()
        external
        whenRecipientNotZeroAddress
        whenDepositLimitRespected
        whenRecipientNotContractAddress
        whenAmountIsGreaterThanZero
        whenCallerHasEnoughBalance
    {
        shares = 1000 ether;
        recipient = users.bob;
        uint256 assets = IERC4626(address(multistrategy)).previewMint(shares);

        vm.expectEmit({emitter: address(multistrategy)});
        emit Deposit(users.bob, recipient, assets, shares);

        swapCaller(users.bob);
        IERC4626(address(multistrategy)).mint(shares, recipient);

        // Assert correct amount of shares have been minted to recipient
        uint256 actualShares = IERC20(address(multistrategy)).balanceOf(recipient);
        uint256 expectedShares = shares;
        assertEq(actualShares, expectedShares, "mint");

        // Assert the assets have been deducted from the caller
        uint256 actualUserBalance = IERC20(address(asset)).balanceOf(recipient);
        uint256 expectedUserBalance = 0;
        assertEq(actualUserBalance, expectedUserBalance, "mint user balance");

        // Assert the assets have been transferred to the multistrategy
        uint256 actualMultistrategyBalance = IERC20(address(asset)).balanceOf(address(multistrategy));
        uint256 expectedMultistrategyBalance = assets;
        assertEq(actualMultistrategyBalance, expectedMultistrategyBalance, "mint multistrategy balance");
    }
}