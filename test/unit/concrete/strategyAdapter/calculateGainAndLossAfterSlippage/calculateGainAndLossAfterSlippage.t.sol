// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.8.20 <0.9.0;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { StrategyAdapter_Unit_Shared_Test } from "../../../shared/StrategyAdapter.t.sol";

contract CalculateGainAndLossAfterSlippage_Unit_Concrete_Test is StrategyAdapter_Unit_Shared_Test {
    uint256 gain;
    uint256 loss;
    uint256 withdrawn;
    uint256 toBeWithdrawn;

    function test_CalculateGainAndLossAfterSlippage_NoSlippageLoss()
        external
    {
        gain = 100;
        loss = 0;
        withdrawn = 1000;
        toBeWithdrawn = 1000;

        (uint256 actualGain, uint256 actualLoss) = strategy.calculateGainAndLossAfterSlippage(gain, loss, withdrawn, toBeWithdrawn);
        (uint256 expectedGain, uint256 expectedLoss) = (gain, loss);
        assertEq(actualGain, expectedGain, "gain");
        assertEq(actualLoss, expectedLoss, "loss");
    }

    modifier whenSlippageLoss() {
        _;
    }

    function test_CalculateGainAndLossAfterSlippage_SlippageGreaterThanGain()
        external
        whenSlippageLoss
    {
        gain = 100;
        loss = 0;
        withdrawn = 800;
        toBeWithdrawn = 1000;

        (uint256 actualGain, uint256 actualLoss) = strategy.calculateGainAndLossAfterSlippage(gain, loss, withdrawn, toBeWithdrawn);
        (uint256 expectedGain, uint256 expectedLoss) = (0, 100);
        assertEq(actualGain, expectedGain, "gain");
        assertEq(actualLoss, expectedLoss, "loss");
    }

    modifier whenSlippageLossSmallerThanGain() {
        _;
    }

    function test_CalculateGainAndLossAfterSlippage_SlippageSmallerThanGain()
        external
        whenSlippageLoss
        whenSlippageLossSmallerThanGain
    {
        gain = 100;
        loss = 0;
        withdrawn = 950;
        toBeWithdrawn = 1000;

        (uint256 actualGain, uint256 actualLoss) = strategy.calculateGainAndLossAfterSlippage(gain, loss, withdrawn, toBeWithdrawn);
        (uint256 expectedGain, uint256 expectedLoss) = (50, 0);
        assertEq(actualGain, expectedGain, "gain");
        assertEq(actualLoss, expectedLoss, "loss");
    }
}