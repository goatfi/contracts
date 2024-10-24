// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.8.20 <0.9.0;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { StrategyAdapter_Integration_Shared_Test } from "../../../shared/StrategyAdapter.t.sol";
import { IStrategyAdapterMock } from "../../../../shared/TestInterfaces.sol";

contract CalculateGainAndLoss_Integration_Concrete_Test is StrategyAdapter_Integration_Shared_Test {

    uint256 currentAssets = 0;
    uint256 totalDebt = 0;

    function test_CalculateGainAndLoss_CurrentAssetsZero_TotalDebtZero()
        external
    {
        (uint256 actualGain, uint256 actualLoss) = IStrategyAdapterMock(address(strategy)).calculateGainAndLoss(currentAssets);
        (uint256 expectedGain, uint256 expectedLoss) = (0, 0);
        assertEq(actualGain, expectedGain);
        assertEq(actualLoss, expectedLoss);
    }

    modifier whenTotalDebtNotZero() {
        requestCredit(address(strategy), 1000 ether);
        _;
    }

    function test_CalculateGainAndLoss_CurrentAssetsZero()
        external
        whenTotalDebtNotZero
    {
        totalDebt = multistrategy.getStrategyParameters(address(strategy)).totalDebt;

        (uint256 actualGain, uint256 actualLoss) = IStrategyAdapterMock(address(strategy)).calculateGainAndLoss(currentAssets);
        (uint256 expectedGain, uint256 expectedLoss) = (0, totalDebt);
        assertEq(actualGain, expectedGain);
        assertEq(actualLoss, expectedLoss);
    }

    modifier whenCurrentAssetsNotZero() {
        currentAssets = 1000 ether;
        _;
    }

    function test_CalculateGainAndLoss_TotalDebtZero()
        external
        whenCurrentAssetsNotZero
    {
        (uint256 actualGain, uint256 actualLoss) = IStrategyAdapterMock(address(strategy)).calculateGainAndLoss(currentAssets);
        (uint256 expectedGain, uint256 expectedLoss) = (currentAssets, 0);
        assertEq(actualGain, expectedGain);
        assertEq(actualLoss, expectedLoss);
    }

    function test_CalculateGainAndLoss_CurrentAssetsGreaterThanTotalDebt() 
        external
        whenCurrentAssetsNotZero
        whenTotalDebtNotZero
    {
        currentAssets = 1100 ether;
        totalDebt = multistrategy.getStrategyParameters(address(strategy)).totalDebt;

        (uint256 actualGain, uint256 actualLoss) = IStrategyAdapterMock(address(strategy)).calculateGainAndLoss(currentAssets);
        (uint256 expectedGain, uint256 expectedLoss) = (currentAssets - totalDebt, 0);
        assertEq(actualGain, expectedGain);
        assertEq(actualLoss, expectedLoss);
    }

    function test_CalculateGainAndLoss_CurrentAssetsLowerThanTotalDebt() 
        external
        whenCurrentAssetsNotZero
        whenTotalDebtNotZero
    {
        currentAssets = 900 ether;
        totalDebt = multistrategy.getStrategyParameters(address(strategy)).totalDebt;

        (uint256 actualGain, uint256 actualLoss) = IStrategyAdapterMock(address(strategy)).calculateGainAndLoss(currentAssets);
        (uint256 expectedGain, uint256 expectedLoss) = (0, totalDebt - currentAssets);
        assertEq(actualGain, expectedGain);
        assertEq(actualLoss, expectedLoss);
    }
}