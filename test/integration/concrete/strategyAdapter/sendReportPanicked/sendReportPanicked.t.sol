// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.8.20 <0.9.0;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { StrategyAdapter_Integration_Shared_Test } from "../../../shared/StrategyAdapter.t.sol";
import { IStrategyAdapterMock } from "../../../../shared/TestInterfaces.sol";
import { IMultistrategyManageable } from "interfaces/infra/multistrategy/IMultistrategyManageable.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";
import { Errors } from "src/infra/libraries/Errors.sol";

contract SendReportPanicked_Integration_Concrete_Test is StrategyAdapter_Integration_Shared_Test {
    function test_RevertWhen_CallerNotOwner() external {
        // Change caller to bob
        swapCaller(users.bob);

        // Expect it to revert
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, users.bob));
        strategy.sendReportPanicked();
    }

    modifier whenCallerOwner() {
        _;
    }

    function test_RevertWhen_ContractNotPaused()
        external
        whenCallerOwner
    {
        vm.expectRevert(abi.encodeWithSelector(Pausable.ExpectedPause.selector));
        strategy.sendReportPanicked();
    }

    modifier whenContractPaused() {
        strategy.panic();
        _;
    }

    modifier whenGain(uint256 _amount) {
        requestCredit(address(strategy), 1000 ether);
        IStrategyAdapterMock(address(strategy)).earn(_amount);
        _;
    }

    modifier whenLoss(uint256 _amount) {
        requestCredit(address(strategy), 1000 ether);
        IStrategyAdapterMock(address(strategy)).lose(_amount);
        _;
    }

    function test_SendReportPanicked_ZeroCurrentAssets()
        external
        whenCallerOwner
        whenLoss(1000 ether)
        whenContractPaused
    {

        strategy.sendReportPanicked();

        // Assert that the strategy repaid 0 tokens
        uint256 actualMultistrategyBalance = IERC20(strategy.baseAsset()).balanceOf(address(multistrategy));
        uint256 expectedMultistrategyBalance = 0;
        assertEq(actualMultistrategyBalance, expectedMultistrategyBalance, "sendReportPanicked, multistrategy balance");

        // Assert that the strategy report a 0 gain
        uint256 actualFeeRecipientBalance = IERC20(strategy.baseAsset()).balanceOf(users.feeRecipient);
        uint256 expectedFeeRecipientBalance = 0;
        assertEq(actualFeeRecipientBalance, expectedFeeRecipientBalance, "sendReportPanicked, fee recipient balance");

        // Assert the debt of this strategy is now 0.
        uint256 actualStrategyDebt = multistrategy.getStrategyParameters(address(strategy)).totalDebt;
        uint256 expectedStrategyDebt = 0;
        assertEq(actualStrategyDebt, expectedStrategyDebt, "sendReportPanicked, strategy debt");
    }

    modifier whenCurrentAssetsNotZero() {
        _;
    }

    function test_SendReport_StrategyNotRetired_Gain()
        external
        whenCallerOwner
        whenGain(100 ether)
        whenContractPaused
        whenCurrentAssetsNotZero
    {
        strategy.sendReportPanicked();

        // Assert that the strategy repaid the gain
        uint256 actualMultistrategyBalance = IERC20(strategy.baseAsset()).balanceOf(address(multistrategy));
        uint256 expectedMultistrategyBalance = 95 ether;
        assertEq(actualMultistrategyBalance, expectedMultistrategyBalance, "sendReportPanicked, multistrategy balance");

        // Assert that the strategy has the same balance of assets as debt amount
        uint256 actualStrategyDebt = multistrategy.getStrategyParameters(address(strategy)).totalDebt;
        uint256 actualStrategyTotalAssets = IERC20(strategy.baseAsset()).balanceOf(address(strategy));
        assertEq(actualStrategyDebt, actualStrategyTotalAssets, "sendReportPanicked, assets and debt match");
    }

    function test_SendReport_StrategyNotRetired_Loss()
        external
        whenCallerOwner
        whenLoss(100 ether)
        whenContractPaused
        whenCurrentAssetsNotZero
    {
        strategy.sendReportPanicked();

        // Assert that the strategy hasn't repaid anything
        uint256 actualMultistrategyBalance = IERC20(strategy.baseAsset()).balanceOf(address(multistrategy));
        uint256 expectedMultistrategyBalance = 0 ether;
        assertEq(actualMultistrategyBalance, expectedMultistrategyBalance, "sendReportPanicked, multistrategy balance");

        // Assert that the strategy has the same balance of assets as debt amount
        uint256 actualStrategyDebt = multistrategy.getStrategyParameters(address(strategy)).totalDebt;
        uint256 actualStrategyTotalAssets = IERC20(strategy.baseAsset()).balanceOf(address(strategy));
        assertEq(actualStrategyDebt, actualStrategyTotalAssets, "sendReportPanicked, assets and debt match");
    }

    modifier whenStrategyReired() {
        IMultistrategyManageable(address(multistrategy)).retireStrategy(address(strategy));
        _;
    }

    function test_SendReport_Gain()
        external
        whenCallerOwner
        whenGain(100 ether)
        whenContractPaused
        whenCurrentAssetsNotZero
        whenStrategyReired
    {
        strategy.sendReportPanicked();

        // Assert that the strategy repaid the gain
        uint256 actualMultistrategyBalance = IERC20(strategy.baseAsset()).balanceOf(address(multistrategy));
        uint256 expectedMultistrategyBalance = 1095 ether;
        assertEq(actualMultistrategyBalance, expectedMultistrategyBalance, "sendReportPanicked, multistrategy balance");

        // Assert that the strategy total debt is 0
        uint256 actualStrategyDebt = multistrategy.getStrategyParameters(address(strategy)).totalDebt;
        uint256 expectedStrategyTotalDebt = 0;
        assertEq(actualStrategyDebt, expectedStrategyTotalDebt, "sendReportPanicked, strategy total debt");

        // Assert that the strategy total assets is 0
        uint256 actualStrategyTotalAssets = IERC20(strategy.baseAsset()).balanceOf(address(strategy));
        uint256 expectedStrategyTotalAssets = 0;
        assertEq(actualStrategyTotalAssets, expectedStrategyTotalAssets, "sendReportPanicked, strategy total assets");
    }

    function test_SendReport_Loss()
        external
        whenCallerOwner
        whenLoss(100 ether)
        whenContractPaused
        whenCurrentAssetsNotZero
        whenStrategyReired
    {
        strategy.sendReportPanicked();

        // Assert that the strategy repaid the loss
        uint256 actualMultistrategyBalance = IERC20(strategy.baseAsset()).balanceOf(address(multistrategy));
        uint256 expectedMultistrategyBalance = 900 ether;
        assertEq(actualMultistrategyBalance, expectedMultistrategyBalance, "sendReportPanicked, multistrategy balance");

        // Assert that the strategy total debt is 0
        uint256 actualStrategyDebt = multistrategy.getStrategyParameters(address(strategy)).totalDebt;
        uint256 expectedStrategyTotalDebt = 0;
        assertEq(actualStrategyDebt, expectedStrategyTotalDebt, "sendReportPanicked, strategy total debt");

        // Assert that the strategy total assets is 0
        uint256 actualStrategyTotalAssets = IERC20(strategy.baseAsset()).balanceOf(address(strategy));
        uint256 expectedStrategyTotalAssets = 0;
        assertEq(actualStrategyTotalAssets, expectedStrategyTotalAssets, "sendReportPanicked, strategy total assets");
    }
}