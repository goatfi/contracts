// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.8.20 <0.9.0;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import { IERC4626, StrategyAdapter_Integration_Shared_Test } from "../../../shared/StrategyAdapter.t.sol";
import { IStrategyAdapterMock } from "../../../../shared/TestInterfaces.sol";

contract CalculateAmountToBeWithdrawn_Integration_Concrete_Test is StrategyAdapter_Integration_Shared_Test {
    uint256 repayAmount = 0;
    uint256 gain = 0;

    function test_CalculateAmountToBeWithdrawn_ExceedingDebtZero_RepayAmountZero_GainZero()
        external
    {

        // Assert that it has to withdrawn 0
        uint256 actualAmountToBeWithdrawn = IStrategyAdapterMock(address(strategy)).calculateAmountToBeWithdrawn(repayAmount, gain);
        uint256 expectedAmountToBeWithdrawn = 0;
        assertEq(actualAmountToBeWithdrawn, expectedAmountToBeWithdrawn);
    }

    modifier whenGainNotZero() {
        gain = 100 * 10 ** decimals;
        _;
    }

    function test_CalculateAmountToBeWithdrawn_ExceedingDebtZero_RepayAmountZero()
        external
        whenGainNotZero
    {
        // Assert that it has to withdrawn the gain
        uint256 actualAmountToBeWithdrawn = IStrategyAdapterMock(address(strategy)).calculateAmountToBeWithdrawn(repayAmount, gain);
        uint256 expectedAmountToBeWithdrawn = gain;
        assertEq(actualAmountToBeWithdrawn, expectedAmountToBeWithdrawn);
    }

    modifier whenRepayAmountNotZero() {
        repayAmount = 100 * 10 ** decimals;
        _;
    }

    function test_CalculateAmountToBeWithdrawn_ExceedingDebtZero_GainZero() 
        external
        whenRepayAmountNotZero
    {
        // Assert that it has to withdrawn 0
        uint256 actualAmountToBeWithdrawn = IStrategyAdapterMock(address(strategy)).calculateAmountToBeWithdrawn(repayAmount, gain);
        uint256 expectedAmountToBeWithdrawn = 0;
        assertEq(actualAmountToBeWithdrawn, expectedAmountToBeWithdrawn);
    }

    function test_CalculateAmountToBeWithdrawn_ExceedingDebtZero()
        external
        whenRepayAmountNotZero
        whenGainNotZero
    {
        // Assert that it has to withdrawn the gain
        uint256 actualAmountToBeWithdrawn = IStrategyAdapterMock(address(strategy)).calculateAmountToBeWithdrawn(repayAmount, gain);
        uint256 expectedAmountToBeWithdrawn = gain;
        assertEq(actualAmountToBeWithdrawn, expectedAmountToBeWithdrawn);
    }

    modifier whenExceedingDebtNotZero() {
        requestCredit(address(strategy), 1000 * 10 ** decimals);
        multistrategy.setStrategyDebtRatio(address(strategy), 5_000);
        _;
    }

    function test_CalculateAmountToBeWithdrawn_RepayAmountZero_GainZero() 
        external
        whenExceedingDebtNotZero
    {
        // Assert that it has to withdrawn 0
        uint256 actualAmountToBeWithdrawn = IStrategyAdapterMock(address(strategy)).calculateAmountToBeWithdrawn(repayAmount, gain);
        uint256 expectedAmountToBeWithdrawn = 0;
        assertEq(actualAmountToBeWithdrawn, expectedAmountToBeWithdrawn);
    }

    function test_CalculateAmountToBeWithdrawn_RepayAmountZero()
        external
        whenExceedingDebtNotZero
        whenGainNotZero
    {
        // Assert that it has to withdrawn the gain
        uint256 actualAmountToBeWithdrawn = IStrategyAdapterMock(address(strategy)).calculateAmountToBeWithdrawn(repayAmount, gain);
        uint256 expectedAmountToBeWithdrawn = gain;
        assertEq(actualAmountToBeWithdrawn, expectedAmountToBeWithdrawn);
    }

    function test_CalculateAmountToBeWithdrawn_GainZero_ExceedingDebtWithSlippageGreaterThanRepayAmount()
        external
        whenExceedingDebtNotZero
        whenRepayAmountNotZero
    {
        // Assert that it has to withdrawn the gain
        uint256 actualAmountToBeWithdrawn = IStrategyAdapterMock(address(strategy)).calculateAmountToBeWithdrawn(repayAmount, gain);
        uint256 expectedAmountToBeWithdrawn = repayAmount;
        assertEq(actualAmountToBeWithdrawn, expectedAmountToBeWithdrawn);
    }

    function test_CalculateAmountToBeWithdrawn_GainZero_ExceedingDebtWithSlippageLowerThanRepayAmount()
        external
        whenExceedingDebtNotZero
        whenRepayAmountNotZero
    {
        repayAmount = 600 * 10 ** decimals;

        // Assert that it has to withdrawn the gain
        uint256 actualAmountToBeWithdrawn = IStrategyAdapterMock(address(strategy)).calculateAmountToBeWithdrawn(repayAmount, gain);
        uint256 expectedAmountToBeWithdrawn = 500 * 10 ** decimals;
        assertEq(actualAmountToBeWithdrawn, expectedAmountToBeWithdrawn);
    }

    function test_CalculateAmountToBeWithdrawn_ExceedingDebtWithSlippageGreaterThanRepayAmount()
        external
        whenExceedingDebtNotZero
        whenRepayAmountNotZero
        whenGainNotZero
    {
        // Assert that it has to withdrawn the gain
        uint256 actualAmountToBeWithdrawn = IStrategyAdapterMock(address(strategy)).calculateAmountToBeWithdrawn(repayAmount, gain);
        uint256 expectedAmountToBeWithdrawn = repayAmount + gain;
        assertEq(actualAmountToBeWithdrawn, expectedAmountToBeWithdrawn);
    }

    function test_CalculateAmountToBeWithdrawn_ExceedingDebtWithSlippageLowerThanRepayAmount()
        external
        whenExceedingDebtNotZero
        whenRepayAmountNotZero
        whenGainNotZero
    {
        repayAmount = 600 * 10 ** decimals;

        // Assert that it has to withdrawn the gain
        uint256 actualAmountToBeWithdrawn = IStrategyAdapterMock(address(strategy)).calculateAmountToBeWithdrawn(repayAmount, gain);
        uint256 expectedAmountToBeWithdrawn = 500 * 10 ** decimals + gain;
        assertEq(actualAmountToBeWithdrawn, expectedAmountToBeWithdrawn);
    }
}