// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { Test } from "forge-std/Test.sol";
import { CurveLendAdapter } from "src/infra/multistrategy/adapters/CurveLendAdapter.sol";
import { StrategyAdapterHarvestable } from "src/abstracts/StrategyAdapterHarvestable.sol";
import { Errors } from "src/infra/libraries/Errors.sol";
import { MockERC4626 } from "@solady/test/utils/mocks/MockERC4626.sol";
import { MockERC20 } from "@solady/test/utils/mocks/MockERC20.sol";
import { MockCurveGauge } from "../../../../mocks/curve/MockCurveGauge.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

contract VerifyRewardToken_Unit_Concrete_Test is Test {
    CurveLendAdapter adapter;
    MockERC4626 vault;
    MockERC20 token;
    MockERC20 weth;
    MockCurveGauge gauge;
    address owner = makeAddr("Owner");
    address notOwner = makeAddr("NotOwner");
    address swapper = makeAddr("Swapper");

    function setUp() public {
        token = new MockERC20("Token", "TKN", 18);
        weth = new MockERC20("WETH", "WETH", 18);
        vault = new MockERC4626(address(token), "LendVault", "", false, 0);
        gauge = new MockCurveGauge(address(vault));

        StrategyAdapterHarvestable.HarvestAddresses memory harvestAddresses = StrategyAdapterHarvestable.HarvestAddresses({
            swapper: swapper,
            wrappedGas: address(weth)
        });

        CurveLendAdapter.CurveLendAddresses memory curveLendAddresses = CurveLendAdapter.CurveLendAddresses({
            vault: address(vault),
            gauge: address(0)
        });

        MockERC4626 multi = new MockERC4626(address(token), "Multi", "", false, 0);
        adapter = new CurveLendAdapter(address(multi), address(token), harvestAddresses, curveLendAddresses, "", "");
        adapter.transferOwnership(owner);
    }

    modifier whenCallerIsOwner() {
        vm.stopPrank();
        vm.startPrank(owner);
        _;
    }

    function test_RevertWhen_GaugeNotSet() whenCallerIsOwner public {
        address reward = makeAddr("Reward");

        vm.expectRevert(abi.encodeWithSelector(Errors.InvalidGauge.selector));
        adapter.addReward(reward);
    }

    function test_RevertWhen_TokenIsLendVault() whenCallerIsOwner public {
        adapter.migrateCurveGauge(address(gauge));

        vm.expectRevert(
            abi.encodeWithSelector(Errors.InvalidRewardToken.selector, address(vault))
        );
        adapter.addReward(address(vault));
    }

    function test_RevertWhen_TokenIsGauge() whenCallerIsOwner public {
        adapter.migrateCurveGauge(address(gauge));

        vm.expectRevert(
            abi.encodeWithSelector(Errors.InvalidRewardToken.selector, address(gauge))
        );
        adapter.addReward(address(gauge));
    }

    function test_RevertWhen_TokenIsAsset() whenCallerIsOwner public {
        adapter.migrateCurveGauge(address(gauge));

        vm.expectRevert(
            abi.encodeWithSelector(Errors.InvalidRewardToken.selector, address(token))
        );
        adapter.addReward(address(token));
    }

    function test_RevertWhen_TokenIsWrappedGas() whenCallerIsOwner public {
        adapter.migrateCurveGauge(address(gauge));

        vm.expectRevert(
            abi.encodeWithSelector(Errors.InvalidRewardToken.selector, address(weth))
        );
        adapter.addReward(address(weth));
    }

    function test_SuccessWhen_ValidRewardToken() whenCallerIsOwner public {
        adapter.migrateCurveGauge(address(gauge));

        address reward = address(new MockERC20("Reward", "RWD", 18));

        // Add reward and ensure no revert
        adapter.addReward(reward);

        // Verify reward added
        address adapterReward = adapter.rewards(0);
        assertEq(adapterReward, reward);

        // Verify max approval was set
        uint256 allowance = IERC20(reward).allowance(address(adapter), swapper);
        assertEq(allowance, type(uint256).max);
    }
}
