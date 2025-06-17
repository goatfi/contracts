// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { Test } from "forge-std/Test.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { StrategyAdapterHarvestable } from "src/abstracts/StrategyAdapterHarvestable.sol";
import { CurveLendAdapter } from "src/infra/multistrategy/adapters/CurveLendAdapter.sol";
import { MockERC4626 } from "solmate/test/utils/mocks/MockERC4626.sol";
import { MockERC20 } from "solmate/test/utils/mocks/MockERC20.sol";
import { MockCurveGauge } from "../../../../mocks/curve/MockCurveGauge.sol";
import { Errors } from "src/infra/libraries/Errors.sol";

contract MigrateCurveGauge_Unit_Concrete_Test is Test {
    CurveLendAdapter adapter;

    MockERC20 token;
    MockERC4626 vault;
    MockCurveGauge gauge;
    address owner = makeAddr('Owner');
    address notOwner = makeAddr('notOwner');

    function setUp() public {
        token = new MockERC20("", "", 18);
        vault = new MockERC4626(token, "","");
        gauge = new MockCurveGauge(address(vault));
        

        StrategyAdapterHarvestable.HarvestAddresses memory harvestAddresses = StrategyAdapterHarvestable.HarvestAddresses({
            swapper: makeAddr('swapper'),
            wrappedGas:  address(new MockERC20("", "", 18))
        });
        CurveLendAdapter.CurveLendAddresses memory curveLendAddresses = CurveLendAdapter.CurveLendAddresses({
            vault: address(vault),
            gauge: address(0)
        });
        MockERC4626 multi = new MockERC4626(token, "","");
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
        adapter.migrateCurveGauge(address(gauge));
        vm.stopPrank();
    }

    modifier whenCallerIsOwner() {
        vm.stopPrank();
        vm.startPrank(owner);
        _;
    }

    function test_RevertWhen_GaugeIsZeroAddress() whenCallerIsOwner public {
        vm.expectRevert(abi.encodeWithSelector(Errors.InvalidGauge.selector));
        adapter.migrateCurveGauge(address(0));
    }

    function test_RevertWhen_LPTokenDoesNotMatch() whenCallerIsOwner public {
        MockERC20 wrongVault = new MockERC20("Wrong", "WRONG", 18);
        MockCurveGauge invalidGauge = new MockCurveGauge(address(wrongVault));

        vm.expectRevert(abi.encodeWithSelector(Errors.InvalidGauge.selector));
        adapter.migrateCurveGauge(address(invalidGauge));
    }

    function test_MigratesGauge_WhenOldGaugeNotSet() whenCallerIsOwner public {
        MockCurveGauge newGauge = new MockCurveGauge(address(vault));

        adapter.migrateCurveGauge(address(newGauge));

        assertEq(vault.allowance(address(adapter), address(newGauge)), type(uint256).max);
        assertEq(address(adapter.curveGauge()), address(newGauge));
    }

    function test_MigratesGauge_WithoutVaultShares() whenCallerIsOwner public {
        MockCurveGauge newGauge = new MockCurveGauge(address(vault));

        adapter.migrateCurveGauge(address(newGauge));

        assertEq(vault.allowance(address(adapter), address(newGauge)), type(uint256).max);
        assertEq(newGauge.balanceOf(address(adapter)), 0);
        assertEq(address(adapter.curveGauge()), address(newGauge));
    }

    function test_MigratesGauge_WhenNoBalanceInOldGauge() whenCallerIsOwner public {
        MockCurveGauge oldGauge = new MockCurveGauge(address(vault));
        MockCurveGauge newGauge = new MockCurveGauge(address(vault));

        adapter.migrateCurveGauge(address(oldGauge));

        assertEq(oldGauge.balanceOf(address(adapter)), 0);
        assertEq(vault.allowance(address(adapter), address(oldGauge)), type(uint256).max);

        adapter.migrateCurveGauge(address(newGauge));

        assertEq(address(adapter.curveGauge()), address(newGauge));
        assertEq(vault.allowance(address(adapter), address(oldGauge)), 0);
        assertEq(vault.allowance(address(adapter), address(newGauge)), type(uint256).max);
    }

    function test_MigratesGauge_WhenBalanceInOldGauge() whenCallerIsOwner public {
        uint256 amount = 10 ether;
        MockCurveGauge oldGauge = new MockCurveGauge(address(vault)); 
        MockCurveGauge newGauge = new MockCurveGauge(address(vault));

        adapter.migrateCurveGauge(address(oldGauge));

        assertEq(oldGauge.balanceOf(address(adapter)), 0);
        assertEq(vault.allowance(address(adapter), address(oldGauge)), type(uint256).max);

        // Mock a deposit
        deal(address(vault), owner, amount);
        vault.approve(address(oldGauge), amount);
        oldGauge.deposit(amount, address(adapter));

        adapter.migrateCurveGauge(address(newGauge));

        assertEq(address(adapter.curveGauge()), address(newGauge));
        assertEq(vault.allowance(address(adapter), address(oldGauge)), 0);
        assertEq(vault.allowance(address(adapter), address(newGauge)), type(uint256).max);
        assertEq(vault.balanceOf(address(oldGauge)), 0);
        assertEq(vault.balanceOf(address(newGauge)), amount);
    }
}