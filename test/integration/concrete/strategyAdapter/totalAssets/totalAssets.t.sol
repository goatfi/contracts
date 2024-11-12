// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.8.20 <0.9.0;

import { IERC4626, StrategyAdapter_Integration_Shared_Test } from "../../../shared/StrategyAdapter.t.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";

contract TotalAssets_Integration_Concrete_Test is StrategyAdapter_Integration_Shared_Test {

    function test_totalAssets_ZeroAssets() external {
        uint256 actualTotalAssets = strategy.totalAssets();
        uint256 expectedTotalAssets = 0;
        assertEq(actualTotalAssets, expectedTotalAssets, "totalAssets, no credit requested");
    }

    modifier whenCreditRequested() {
        requestCredit(address(strategy), 1000 * 10 ** decimals);
        _;
    }

    function test_totalAssets() 
        external
        whenCreditRequested
    {
        uint256 actualTotalAssets = strategy.totalAssets();
        uint256 expectedTotalAssets = 1000 * 10 ** decimals;
        assertEq(actualTotalAssets, expectedTotalAssets, "totalAssets, credit requested");
    }
}