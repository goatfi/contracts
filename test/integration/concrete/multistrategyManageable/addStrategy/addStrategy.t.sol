// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.20 <0.9.0;

import { Multistrategy } from "src/infra/multistrategy/Multistrategy.sol";
import { IERC4626, Multistrategy_Integration_Shared_Test } from "../../../shared/Multistrategy.t.sol";
import { StrategyAdapterMock } from "../../../../mocks/StrategyAdapterMock.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { MStrat } from "src/types/DataTypes.sol";
import { Errors } from "src/infra/libraries/Errors.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

contract AddStrategy_Integration_Concrete_Test is Multistrategy_Integration_Shared_Test {

    uint256 debtRatio = 5_000;
    uint256 minDebtDelta = 100 ether;
    uint256 maxDebtDelta = 100_000 ether;

    function test_RevertWhen_CallerNotOwner() external {
        // Change caller to bob
        swapCaller(users.bob);

        address strategy = makeAddr("strategy");
        
        // Expect a revert
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, users.bob));
        multistrategy.addStrategy(address(strategy), debtRatio, minDebtDelta, maxDebtDelta);
    }

    modifier whenCallerIsOwner() {
        swapCaller(users.owner);
        _;
    }

    /// @dev Deploy and add 10 mock strategies to the multistrategy
    modifier whenActiveStrategiesAtMaximum() {
        // Deployed strategies will have 10% debt ratio
        debtRatio = 1_000;
        
        // Deploy 10 strategies, each with 10% debt ratio
        for (uint256 i = 0; i < 10; i++) {
            StrategyAdapterMock strategy = deployMockStrategyAdapter(address(multistrategy), IERC4626(address(multistrategy)).asset());
            multistrategy.addStrategy(address(strategy), debtRatio, minDebtDelta, maxDebtDelta);
        }
        _;
    }

    function test_RevertWhen_ActiveStrategiesAboveMaximum() 
        external 
        whenCallerIsOwner
        whenActiveStrategiesAtMaximum
    {
        StrategyAdapterMock strategy = deployMockStrategyAdapter(address(multistrategy), IERC4626(address(multistrategy)).asset());

        // Expect a revert
        vm.expectRevert(abi.encodeWithSelector(Errors.MaximumAmountStrategies.selector));
        multistrategy.addStrategy(address(strategy), debtRatio, minDebtDelta, maxDebtDelta);
    }

    modifier whenActiveStrategiesBelowMaximum() {
        _;
    }

    function test_RevertWhen_StrategyIsZeroAddress() 
        external
        whenCallerIsOwner
        whenActiveStrategiesBelowMaximum
    {
        address strategy = address(0);

        // Expect a revert
        vm.expectRevert(abi.encodeWithSelector(Errors.InvalidAddress.selector, strategy));
        multistrategy.addStrategy(address(strategy), debtRatio, minDebtDelta, maxDebtDelta);
    }

    modifier whenNotZeroAddress() {
        _;
    }

    function test_RevertWhen_StrategyIsMultistrategyAddress()
        external
        whenCallerIsOwner
        whenActiveStrategiesBelowMaximum
        whenNotZeroAddress
    {
        address strategy = address(multistrategy);

        // Expect a revert
        vm.expectRevert(abi.encodeWithSelector(Errors.InvalidAddress.selector, strategy));
        multistrategy.addStrategy(address(strategy), debtRatio, minDebtDelta, maxDebtDelta);
    }

    modifier whenNotMultistrategyAddress() {
        _;
    }

    /// @dev Only way to activate a strategy is to add it to the multistrategy
    function test_RevertWhen_StrategyIsActive() 
        external
        whenCallerIsOwner
        whenActiveStrategiesBelowMaximum
        whenNotZeroAddress
        whenNotMultistrategyAddress
    {
        StrategyAdapterMock strategy = deployMockStrategyAdapter(address(multistrategy), IERC4626(address(multistrategy)).asset());
        // We add the strategy
        multistrategy.addStrategy(address(strategy), debtRatio, minDebtDelta, maxDebtDelta);

        // Expect a revert
        vm.expectRevert(abi.encodeWithSelector(Errors.StrategyAlreadyActive.selector, strategy));
        multistrategy.addStrategy(address(strategy), debtRatio, minDebtDelta, maxDebtDelta);
    }

    modifier whenStrategyIsInactive() {
        _;
    }

    /// @dev Testing this requires some setup. As creating a strategy with the wrong base asset
    ///      would revert, as it is checked in the constructor of the StrategyAdapter.
    ///      We need to deploy a need multistrategy with a different token and create a strategy for
    ///      that multistrategy. Revert will happen when we try to add that strategy to the multistrategy
    ///      We're testing here.
    function test_RevertWhen_assetDoNotMatch() 
        external
        whenCallerIsOwner
        whenActiveStrategiesBelowMaximum
        whenNotZeroAddress
        whenNotMultistrategyAddress
        whenStrategyIsInactive
    {
        // Deploy a multistrategy with a different asset
        Multistrategy usdtMultistrategy = new Multistrategy({
            _asset: address(asset) == address(dai) ? address(usdt) : address(dai),
            _manager: users.keeper,
            _protocolFeeRecipient: users.feeRecipient,
            _name: "Multistrategy",
            _symbol: "MULT"
        });
        
        // Deploy a mock strategy for the usdt multistrategy
        StrategyAdapterMock strategy = deployMockStrategyAdapter(address(usdtMultistrategy), IERC4626(address(usdtMultistrategy)).asset());
        
        // Expect a revert
        vm.expectRevert(abi.encodeWithSelector(
            Errors.AssetMismatch.selector, 
            IERC4626(address(multistrategy)).asset(), 
            IERC4626(address(usdtMultistrategy)).asset()
        ));
        multistrategy.addStrategy(address(strategy), debtRatio, minDebtDelta, maxDebtDelta);
    }

    modifier whenAssetMatch() {
        _;
    }

    function test_RevertWhen_MinDebtDeltaIsHigherThanMaxDebtDelta()
        external
        whenCallerIsOwner
        whenActiveStrategiesBelowMaximum
        whenNotZeroAddress
        whenNotMultistrategyAddress
        whenStrategyIsInactive
        whenAssetMatch
    {
        StrategyAdapterMock strategy = deployMockStrategyAdapter(address(multistrategy), IERC4626(address(multistrategy)).asset());
        minDebtDelta = 200_000 ether;
        maxDebtDelta = 100_000 ether;

        // Expect a revert
        vm.expectRevert(abi.encodeWithSelector(Errors.InvalidDebtDelta.selector));
        multistrategy.addStrategy(address(strategy), debtRatio, minDebtDelta, maxDebtDelta);
    }

    /// @dev Le = Lower or Equal
    modifier whenMinDebtDeltaLeMaxDebtDelta() {
        _;
    }

    function test_RevertWhen_DebtRatioSumIsAboveMax()
        external
        whenCallerIsOwner
        whenActiveStrategiesBelowMaximum
        whenNotZeroAddress
        whenNotMultistrategyAddress
        whenStrategyIsInactive
        whenAssetMatch
        whenMinDebtDeltaLeMaxDebtDelta
    {
        StrategyAdapterMock strategy = deployMockStrategyAdapter(address(multistrategy), IERC4626(address(multistrategy)).asset());
        // 110% debt ratio
        debtRatio = 11_000;

        // Expect a revert
        vm.expectRevert(abi.encodeWithSelector(Errors.DebtRatioAboveMaximum.selector, debtRatio));
        multistrategy.addStrategy(address(strategy), debtRatio, minDebtDelta, maxDebtDelta);
    }

    /// @dev Le = Lower or Equal
    modifier whenDebtRatioLeMax() {
        _;
    }

    function test_AddStrategy_NewStrategy()
        external
        whenCallerIsOwner
        whenActiveStrategiesBelowMaximum
        whenNotZeroAddress
        whenNotMultistrategyAddress
        whenStrategyIsInactive
        whenAssetMatch
        whenMinDebtDeltaLeMaxDebtDelta
    {
        StrategyAdapterMock strategy = deployMockStrategyAdapter(address(multistrategy), IERC4626(address(multistrategy)).asset());

        // Expect the relevant event
        vm.expectEmit({ emitter: address(multistrategy) });
        emit StrategyAdded(address(strategy));

        multistrategy.addStrategy(address(strategy), debtRatio, minDebtDelta, maxDebtDelta);

        // Assert than the strategy has been added correctly
        MStrat.StrategyParams memory actualStrategyParams = multistrategy.getStrategyParameters(address(strategy));
        MStrat.StrategyParams memory expectedStrategyParams = MStrat.StrategyParams({
            activation: block.timestamp,
            debtRatio: debtRatio,
            lastReport: block.timestamp,
            minDebtDelta: minDebtDelta,
            maxDebtDelta: maxDebtDelta,
            totalDebt: 0,
            totalGain: 0,
            totalLoss: 0
        });

        uint256 actualMultistrategyDebtRatio = multistrategy.debtRatio();
        uint256 expectedMultistrategyDebtRatio = debtRatio;

        uint256 actualActiveStrategies = multistrategy.activeStrategies();
        uint256 expectedActiveStrategies = 1;

        address actualAddressAtWithdrawOrderPos0 = multistrategy.getWithdrawOrder()[0];
        address expectedAddressAtWithdrawOrderPos0 = address(strategy);
        
        // Assert strategy params
        assertEq(actualStrategyParams.activation, expectedStrategyParams.activation, "addStrategy Params activation");
        assertEq(actualStrategyParams.debtRatio, expectedStrategyParams.debtRatio, "addStrategy Params debtRatio");
        assertEq(actualStrategyParams.lastReport, expectedStrategyParams.lastReport, "addStrategy Params last report");
        assertEq(actualStrategyParams.minDebtDelta, expectedStrategyParams.minDebtDelta, "addStrategy Params min debt delta");
        assertEq(actualStrategyParams.maxDebtDelta, expectedStrategyParams.maxDebtDelta, "addStrategy Params max debt delta");
        assertEq(actualStrategyParams.totalDebt, expectedStrategyParams.totalDebt, "addStrategy Params total debt");
        assertEq(actualStrategyParams.totalGain, expectedStrategyParams.totalGain, "addStrategy Params total gain");
        assertEq(actualStrategyParams.totalLoss, expectedStrategyParams.totalLoss, "addStrategy Params total loss");

        // Assert strategy debt ratio is added to multistrategy debt ratio
        assertEq(actualMultistrategyDebtRatio, expectedMultistrategyDebtRatio, "addStrategy DebtRatio");

        // Assert active strategies is incremented
        assertEq(actualActiveStrategies, expectedActiveStrategies, "addStrategy Active strategies");

        // Assert that the strategy has been put in the 1st position of the withdraw order
        assertEq(actualAddressAtWithdrawOrderPos0, expectedAddressAtWithdrawOrderPos0, "addStrategy withdraw order");
    }
}