// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.20 <0.9.0;

import { Multistrategy } from "src/infra/multistrategy/Multistrategy.sol";
import { Multistrategy_Integration_Shared_Test } from "../../../shared/Multistrategy.t.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { MStrat } from "src/types/DataTypes.sol";
import { Errors } from "src/infra/libraries/Errors.sol";

contract AddStrategy_Integration_Concrete_Test is Multistrategy_Integration_Shared_Test {

    uint256 debtRatio = 5_000;
    uint256 minDebtDelta = 100 ether;
    uint256 maxDebtDelta = 100_000 ether;

    function test_RevertWhen_CallerNotManager() external {
        // Change caller to bob
        swapCaller(users.bob);

        address strategy = makeAddr("strategy");
        
        // Expect a revert
        vm.expectRevert(abi.encodeWithSelector(Errors.CallerNotManager.selector, users.bob));
        multistrategy.addStrategy(strategy, debtRatio, minDebtDelta, maxDebtDelta);
    }

    modifier whenCallerIsManager() {
        swapCaller(users.keeper);
        _;
    }

    /// @dev Deploy and add 10 mock strategies to the mulistrategy
    modifier whenActiveStrategiesAtMaximum() {
        // Deployed strategies will have 10% debt ratio
        debtRatio = 1_000;
        
        // Deploy 10 strategies, each with 10% debt ratio
        for (uint256 i = 0; i < 10; i++) {
            address strategy = deployMockStrategyWrapper(address(multistrategy), multistrategy.depositToken());
            multistrategy.addStrategy(strategy, debtRatio, minDebtDelta, maxDebtDelta);
        }
        _;
    }

    function test_RevertWhen_ActiveStrategiesAboveMaximum() 
        external 
        whenCallerIsManager 
        whenActiveStrategiesAtMaximum
    {
        address strategy = deployMockStrategyWrapper(address(multistrategy), multistrategy.depositToken());

        // Expect a revert
        vm.expectRevert(abi.encodeWithSelector(Errors.MaximumAmountStrategies.selector));
        multistrategy.addStrategy(strategy, debtRatio, minDebtDelta, maxDebtDelta);
    }

    modifier whenActiveStrategiesBelowMaximum() {
        _;
    }

    function test_RevertWhen_StrategyIsZeroAddress() 
        external
        whenCallerIsManager
        whenActiveStrategiesBelowMaximum
    {
        address strategy = address(0);

        // Expect a revert
        vm.expectRevert(abi.encodeWithSelector(Errors.InvalidAddress.selector, strategy));
        multistrategy.addStrategy(strategy, debtRatio, minDebtDelta, maxDebtDelta);
    }

    modifier whenNotZeroAddress() {
        _;
    }

    function test_RevertWhen_StrategyIsMultistrategyAddress()
        external
        whenCallerIsManager
        whenActiveStrategiesBelowMaximum
        whenNotZeroAddress
    {
        address strategy = address(multistrategy);

        // Expect a revert
        vm.expectRevert(abi.encodeWithSelector(Errors.InvalidAddress.selector, strategy));
        multistrategy.addStrategy(strategy, debtRatio, minDebtDelta, maxDebtDelta);
    }

    modifier whenNotMultistrategyAddress() {
        _;
    }

    /// @dev Only way to activate a strategy is to add it to the multistrategy
    function test_RevertWhen_StrategyIsActive() 
        external
        whenCallerIsManager
        whenActiveStrategiesBelowMaximum
        whenNotZeroAddress
        whenNotMultistrategyAddress
    {
        address strategy = deployMockStrategyWrapper(address(multistrategy), multistrategy.depositToken());
        // We add the strategy
        multistrategy.addStrategy(strategy, debtRatio, minDebtDelta, maxDebtDelta);

        // Expect a revert
        vm.expectRevert(abi.encodeWithSelector(Errors.StrategyAlreadyActive.selector, strategy));
        multistrategy.addStrategy(strategy, debtRatio, minDebtDelta, maxDebtDelta);
    }

    modifier whenStrategyIsInactive() {
        _;
    }

    /// @dev Testing this requires some setup. As creating a strategy with the wrong deposit token
    ///      would revert, as it is checked in the constructor of the StrategyWrapper.
    ///      We need to deploy a need multistrategy with a different token and create a strategy for
    ///      that multistrategy. Revert will happen when we try to add that strategy to the multistrategy
    ///      We're testing here.
    function test_RevertWhen_DepositTokenDoNotMatch() 
        external
        whenCallerIsManager
        whenActiveStrategiesBelowMaximum
        whenNotZeroAddress
        whenNotMultistrategyAddress
        whenStrategyIsInactive
    {
        // Deploy a multistrategy with a different depositToken
        Multistrategy usdtMultistrategy = new Multistrategy({
            _depositToken: address(usdt),
            _manager: users.keeper,
            _protocolFeeRecipient: users.feeRecipient,
            _name: "Goat USDT",
            _symbol: "GUSDT"
        });
        
        // Deploy a mock strategy for the usdt multistrategy
        address strategy = deployMockStrategyWrapper(address(usdtMultistrategy), usdtMultistrategy.depositToken());
        
        // Expect a revert
        vm.expectRevert(abi.encodeWithSelector(
            Errors.DepositTokenMissmatch.selector, 
            multistrategy.depositToken(), 
            usdtMultistrategy.depositToken()
        ));
        multistrategy.addStrategy(strategy, debtRatio, minDebtDelta, maxDebtDelta);
    }

    modifier whenDepositTokenMatch() {
        _;
    }

    function test_RevertWhen_MinDebtDeltaIsHigherThanMaxDebtDelta()
        external
        whenCallerIsManager
        whenActiveStrategiesBelowMaximum
        whenNotZeroAddress
        whenNotMultistrategyAddress
        whenStrategyIsInactive
        whenDepositTokenMatch
    {
        address strategy = deployMockStrategyWrapper(address(multistrategy), multistrategy.depositToken());
        minDebtDelta = 200_000 ether;
        maxDebtDelta = 100_000 ether;

        // Expect a revert
        vm.expectRevert(abi.encodeWithSelector(Errors.InvalidDebtDelta.selector));
        multistrategy.addStrategy(strategy, debtRatio, minDebtDelta, maxDebtDelta);
    }

    /// @dev Lq = Lower or Equal
    modifier whenMinDebtDeltaLqMaxDebtDelta() {
        _;
    }

    function test_RevertWhen_DebtRatioSumIsAboveMax()
        external
        whenCallerIsManager
        whenActiveStrategiesBelowMaximum
        whenNotZeroAddress
        whenNotMultistrategyAddress
        whenStrategyIsInactive
        whenDepositTokenMatch
        whenMinDebtDeltaLqMaxDebtDelta
    {
        address strategy = deployMockStrategyWrapper(address(multistrategy), multistrategy.depositToken());
        // 110% debt raito
        debtRatio = 11_000;

        // Expect a revert
        vm.expectRevert(abi.encodeWithSelector(Errors.DebtRatioAboveMaximum.selector, debtRatio));
        multistrategy.addStrategy(strategy, debtRatio, minDebtDelta, maxDebtDelta);
    }

    /// @dev Lq = Lower or Equal
    modifier whenDebtRatioLqMax() {
        _;
    }

    function test_AddStrategy_NewStrategy()
        external
        whenCallerIsManager
        whenActiveStrategiesBelowMaximum
        whenNotZeroAddress
        whenNotMultistrategyAddress
        whenStrategyIsInactive
        whenDepositTokenMatch
        whenMinDebtDeltaLqMaxDebtDelta
    {
        address strategy = deployMockStrategyWrapper(address(multistrategy), multistrategy.depositToken());

        // Expect the relevant event
        vm.expectEmit({ emitter: address(multistrategy) });
        emit StrategyAdded(strategy);

        multistrategy.addStrategy(strategy, debtRatio, minDebtDelta, maxDebtDelta);

        // Assert than the strategy has been added correctly
        MStrat.StrategyParams memory actualStrategyParams = multistrategy.getStrategyParameters(strategy);
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
        address expectedAddressAtWithdrawOrderPos0 = strategy;
        
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