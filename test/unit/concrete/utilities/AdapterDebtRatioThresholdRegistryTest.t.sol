// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import { Test} from "forge-std/Test.sol";
import { AdapterDebtRatioThresholdRegistry } from "src/infra/utilities/AdapterDebtRatioThresholdRegistry.sol";
import { Errors } from "src/infra/libraries/Errors.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

contract AdapterDebtRatioThresholdRegistryTest is Test {
    AdapterDebtRatioThresholdRegistry internal registry;

    address internal owner     = address(0xA11CE);
    address internal attacker  = address(0xB0B);
    address internal adapter   = address(0xC0FFEE);

    function setUp() public {
        registry = new AdapterDebtRatioThresholdRegistry(owner);
    }
    
    function test_SetThreshold_RevertWhen_callerNotOwner() public {
        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, attacker));
        registry.setThreshold(adapter, 42);
    }

    function test_SetThreshold_RevertWhen_ThresholdAboveMaximum() public {
        uint256 aboveMax = 10_001;
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(Errors.DebtRatioAboveMaximum.selector, aboveMax));
        registry.setThreshold(adapter, aboveMax);
    }

    function test_setThreshold() public {
        uint256 threshold = 7_500;

        vm.prank(owner);
        registry.setThreshold(adapter, threshold);

        assertEq(registry.threshold(adapter), threshold, "Threshold not stored correctly");
    }

    function test_RemoveThreshold_RevertWhen_callerNotOwner() public {
        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, attacker));
        registry.removeThreshold(adapter);
    }

    function test_RemoveThreshold() public {
        vm.prank(owner);
        registry.setThreshold(adapter, 1_000);

        vm.prank(owner);
        registry.removeThreshold(adapter);

        assertEq(registry.threshold(adapter), 0, "Threshold not reset to zero");
    }
}
