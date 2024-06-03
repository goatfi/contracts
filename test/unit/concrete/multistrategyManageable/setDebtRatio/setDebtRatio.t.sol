// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.20 <0.9.0;

import { Multistrategy_Unit_Shared_Test } from "../../../shared/Multistrategy.t.sol";
import { Errors } from "src/infra/libraries/Errors.sol";

contract SetDebtRatio_Unit_Concrete_Test is Multistrategy_Unit_Shared_Test {
    function test_RevertWhen_CallerNotManager() external {
        // Change caller to bob
        swapCaller(users.bob);
        // 10% debt ratio
        uint256 debtRatio = 1_000;
        
        // Expect a revert
        vm.expectRevert(abi.encodeWithSelector(Errors.CallerNotManager.selector, users.bob));
        multistrategy.setDebtRatio(debtRatio);
    }

    modifier whenCallerIsManager() {
        swapCaller(users.keeper);
        _;
    }

    function test_RevertWhen_DebtRatioAboveMaximumBPS() external whenCallerIsManager {
        // 1,000% debt ratio.
        uint256 debtRatio = 100_000;

        // Expect a revert
        vm.expectRevert(abi.encodeWithSelector(Errors.DebtRatioAboveMaximum.selector, debtRatio));
        multistrategy.setDebtRatio(debtRatio);
    }

    modifier whenBelowMaximumDebtRatio() {
        _;
    }

    function test_SetDebtRatio_SameDebtRatio()
        external
        whenCallerIsManager
        whenBelowMaximumDebtRatio
    {
        // 50% debt ratio.
        uint256 debtRatio = 9_000;
        
        // Expect the relevant event to be emitted.
        vm.expectEmit({ emitter: address(multistrategy) });
        emit DebtRatioSet(debtRatio);

        multistrategy.setDebtRatio(debtRatio);

        // Assert debt ratio has been set
        uint256 actualDebtRatio = multistrategy.debtRatio();
        uint256 expectedDebtRatio = debtRatio;
        assertEq(actualDebtRatio, expectedDebtRatio, "debt ratio");
    }

    function test_SetDebtRatio_ZeroDebtRatio()
        external
        whenCallerIsManager
        whenBelowMaximumDebtRatio
    {
        // 0% debt ratio.
        uint256 debtRatio = 0;

        // Expect the relevant event to be emitted.
        vm.expectEmit({ emitter: address(multistrategy) });
        emit DebtRatioSet(debtRatio);

        multistrategy.setDebtRatio(debtRatio);

        // Assert debt ratio has been set
        uint256 actualDebtRatio = multistrategy.debtRatio();
        uint256 expectedDebtRatio = debtRatio;
        assertEq(actualDebtRatio, expectedDebtRatio, "debt ratio");
    }

    modifier whenNotZeroDebtRatio() {
        _;
    }

    function test_SetDebtRatio_NewDebtRatio()
        external
        whenCallerIsManager
        whenBelowMaximumDebtRatio
        whenNotZeroDebtRatio
    {
        // 50% debt ratio.
        uint256 debtRatio = 5_000;

        // Expect the relevant event to be emitted.
        vm.expectEmit({ emitter: address(multistrategy) });
        emit DebtRatioSet(debtRatio);

        multistrategy.setDebtRatio(debtRatio);

        // Assert debt ratio has been set
        uint256 actualDebtRatio = multistrategy.debtRatio();
        uint256 expectedDebtRatio = debtRatio;
        assertEq(actualDebtRatio, expectedDebtRatio, "debt ratio");
    }
}