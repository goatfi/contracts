// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { Test } from "forge-std/Test.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { StrategyAdapterHarvestable } from "src/abstracts/StrategyAdapterHarvestable.sol";
import { CurveLendAdapter } from "src/infra/multistrategy/adapters/CurveLendAdapter.sol";
import { MockERC4626 } from "@solady/test/utils/mocks/MockERC4626.sol";
import { MockERC20 } from "@solady/test/utils/mocks/MockERC20.sol";
import { Errors } from "src/infra/libraries/Errors.sol";

contract SetCurveGauge_Unit_Concrete_Test is Test {
    CurveLendAdapter adapter;

    MockERC4626 vault;
    address owner = makeAddr('Owner');
    address notOwner = makeAddr('notOwner');
    address curveGauge = makeAddr("CurveGauge");

    function setUp() public {
        MockERC20 token = new MockERC20("", "", 18);
        MockERC20 weth = new MockERC20("", "", 18);
        vault = new MockERC4626(address(token), "","", false, 0);
        

        StrategyAdapterHarvestable.HarvestAddresses memory harvestAddresses = StrategyAdapterHarvestable.HarvestAddresses({
            swapper: makeAddr('swapper'),
            wrappedGas:  address(weth)
        });
        CurveLendAdapter.CurveLendAddresses memory curveLendAddresses = CurveLendAdapter.CurveLendAddresses({
            vault: address(vault),
            gauge: address(0)
        });
        MockERC4626 multi = new MockERC4626(address(token), "","", false, 0);
        adapter = new CurveLendAdapter(address(multi), address(token), harvestAddresses, curveLendAddresses, "", "");
        adapter.transferOwnership(owner);
    }

    function test_RevertWhen_CallerNotOwner() public {
        vm.startPrank(notOwner);
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                notOwner
            )
        );
        adapter.setCurveGauge(curveGauge);
        vm.stopPrank();
    }

    modifier whenCallerIsOwner() {
        vm.stopPrank();
        vm.startPrank(owner);
        _;
    }

    function test_RevertWhen_GaugeAlreadySet() whenCallerIsOwner public {
        // First set to a valid gauge
        adapter.setCurveGauge(curveGauge);

        // Try to set again
        address newGauge = makeAddr("AnotherGauge");

        vm.expectRevert(abi.encodeWithSelector(Errors.InvalidGauge.selector));
        adapter.setCurveGauge(newGauge);
    }

    function test_RevertWhen_NewGaugeIsZero() whenCallerIsOwner public {
        vm.expectRevert(abi.encodeWithSelector(Errors.InvalidGauge.selector));
        adapter.setCurveGauge(address(0));
    }

    function test_SetCurveGauge_Successfully() whenCallerIsOwner public {
        // Check that it can be set correctly
        adapter.setCurveGauge(curveGauge);

        // Verify that the internal state is correctly set
        assertEq(address(adapter.curveGauge()), curveGauge);

        // Check approval set to max
        uint allowance = IERC20(address(vault)).allowance(address(adapter), curveGauge);
        assertEq(allowance, type(uint256).max);
    }
}