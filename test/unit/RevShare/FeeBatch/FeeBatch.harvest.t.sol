// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import { RevenueShareTestBase } from "../RevenueShareBase.t.sol";

contract FeeBatchHarvestTest is RevenueShareTestBase {

    uint256 depositValue = 0.1 ether;

    function setUp() public override {
        RevenueShareTestBase.setUp();
    }

    modifier with_WETH() {
        weth.deposit{value: depositValue}();
        weth.transfer(address(feeBatch), weth.balanceOf(address(this)));
        _;
    }

    function test_Harvest() with_WETH public {
        feeBatch.harvest();

        assertEq(weth.balanceOf(address(feeBatch)), 0);
        assertEq(weth.balanceOf(address(rewardPool)), depositValue);
    }

    function test_SendHarvestGas_EmptyHarvester() with_WETH public {
        feeBatch.setSendHarvesterGas(true);
        feeBatch.setHarvesterConfig(HARVESTER, 0.01 ether);

        feeBatch.harvest();

        assertLt(weth.balanceOf(address(rewardPool)), depositValue);
        assertGt(HARVESTER.balance, 0);
    }

    function test_SendHarvestGas_NonEmptyHarvester() with_WETH public {
        uint256 harvesterInitialBalance = 0.005 ether;

        feeBatch.setSendHarvesterGas(true);
        feeBatch.setHarvesterConfig(HARVESTER, 0.01 ether);
        deal(HARVESTER, harvesterInitialBalance);

        feeBatch.harvest();

        assertEq(weth.balanceOf(address(rewardPool)), depositValue - harvesterInitialBalance);
        assertGt(HARVESTER.balance, 0);
    }

    /// @notice If native balance on FeeBatch isn't to fill the harvester, 
    /// all funds will be sent to fill the harvester first.
    function test_SendHarvestGas_NotEnough() with_WETH public {
        feeBatch.setSendHarvesterGas(true);
        feeBatch.setHarvesterConfig(HARVESTER, 1 ether);

        feeBatch.harvest();

        assertEq(weth.balanceOf(address(rewardPool)), 0);
        assertGe(HARVESTER.balance, depositValue);
    }
}