// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Test } from "forge-std/Test.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import { Multistrategy } from "src/infra/multistrategy/Multistrategy.sol";
import { StrategyAdapter } from "src/abstracts/StrategyAdapter.sol";
import { Users } from "../../utils/Types.sol";
import { IMultistrategyManageable } from "interfaces/infra/multistrategy/IMultistrategyManageable.sol";
import { IStrategyAdapter } from "interfaces/infra/multistrategy/IStrategyAdapter.sol";
import { IStrategyAdapterHarvestable } from "interfaces/infra/multistrategy/IStrategyAdapterHarvestable.sol";
import { MStrat } from "src/types/DataTypes.sol";

contract AdapterHandler is Test {
    Multistrategy public multistrategy;
    StrategyAdapter public adapter;
    Users public users;

    address public asset;
    bool harvest;

    uint256 public ghost_deposited;
    uint256 public ghost_withdrawn;
    uint256 public ghost_yieldTime;

    constructor(Multistrategy _multistrategy, StrategyAdapter _adapter, Users memory _users, bool _harvest) {
        multistrategy = _multistrategy;
        adapter = _adapter;
        users = _users;
        harvest = _harvest;
        asset = multistrategy.asset();
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    MODIFIERS
    //////////////////////////////////////////////////////////////////////////*/

    modifier whenNotPaused() {
        if(adapter.paused()) return;
        _;
    }

    modifier whenAdapterActive() {
        MStrat.StrategyParams memory strategyParams = IMultistrategyManageable(address(multistrategy)).getStrategyParameters(address(adapter));
        if(strategyParams.activation == 0) return;
        _;
    }

    modifier whenAdapterNotActive() {
        MStrat.StrategyParams memory strategyParams = IMultistrategyManageable(address(multistrategy)).getStrategyParameters(address(adapter));
        if(strategyParams.activation != 0) return;
        _;
    }

    modifier whenAdapterRetired() {
        MStrat.StrategyParams memory strategyParams = IMultistrategyManageable(address(multistrategy)).getStrategyParameters(address(adapter));
        if(strategyParams.debtRatio != 0) return;
        _;
    }

    modifier whenNoOutstandingDebt() {
        MStrat.StrategyParams memory strategyParams = IMultistrategyManageable(address(multistrategy)).getStrategyParameters(address(adapter));
        if(strategyParams.totalDebt > 0) return;
        _; 
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     ACTIONS
    //////////////////////////////////////////////////////////////////////////*/

    function addAdapter() whenAdapterNotActive public {
        vm.prank(users.owner); IMultistrategyManageable(address(multistrategy)).addStrategy(address(adapter), 10_000, 0, type(uint256).max);
    }

    function retireAdapter() whenAdapterActive public {
        vm.prank(users.owner); IMultistrategyManageable(address(multistrategy)).retireStrategy(address(adapter));
    }

    function removeAdapter() whenAdapterActive whenAdapterRetired whenNoOutstandingDebt public {
        vm.prank(users.owner); IMultistrategyManageable(address(multistrategy)).removeStrategy(address(adapter));
    }

    function setDebtRatio(uint256 _debtRatio) whenNotPaused whenAdapterActive public {
        _debtRatio = bound(_debtRatio, 0, 10_000);

        vm.warp(block.timestamp + 1 minutes);

        vm.prank(users.keeper); IMultistrategyManageable(address(multistrategy)).setStrategyDebtRatio(address(adapter), _debtRatio);
        vm.prank(users.keeper); IStrategyAdapter(address(adapter)).requestCredit();
        vm.prank(users.keeper); IStrategyAdapter(address(adapter)).sendReport(type(uint256).max);
    }

    function requestCredit() whenNotPaused whenAdapterActive public {
        uint256 availableCredit = multistrategy.creditAvailable(address(adapter));
        if(availableCredit > 1) {
            vm.prank(users.keeper); IStrategyAdapter(address(adapter)).requestCredit();
        }
    }

    function deposit(uint256 _amount) whenNotPaused public {
        if(multistrategy.totalAssets() >= multistrategy.depositLimit()) return;
        uint256 maxDeposit = multistrategy.depositLimit() - multistrategy.totalAssets();
        if(maxDeposit == 0) return;
        _amount = bound(_amount, 1, maxDeposit);
        ghost_deposited += _amount;

        deal(asset, users.bob, _amount);
        vm.prank(users.bob); IERC20(asset).approve(address(multistrategy), _amount);
        vm.prank(users.bob); IERC4626(address(multistrategy)).deposit(_amount, users.bob);
    }

    function withdraw(uint256 _amount) whenNotPaused public {
        uint256 maxWithdraw = IERC4626(address(multistrategy)).maxWithdraw(users.bob);
        if(maxWithdraw == 0) return;

        _amount = bound(_amount, 1, maxWithdraw);
        ghost_withdrawn += _amount;

        vm.warp(block.timestamp + 1 minutes);
        vm.prank(users.bob); IERC4626(address(multistrategy)).withdraw(_amount, users.bob, users.bob);
    }

    function withdrawAll() whenNotPaused public {
        uint256 balance = IERC4626(address(multistrategy)).balanceOf(users.bob);
        if(balance > 0) {
            vm.warp(block.timestamp + 1 minutes);
            vm.prank(users.bob); IERC4626(address(multistrategy)).redeem(balance, users.bob, users.bob);
        }
    }

    function earnYield(uint256 _time) whenNotPaused whenAdapterActive public {
        _time = bound(_time, 1 hours, 30 days);

        ghost_yieldTime += _time;

        vm.warp(block.timestamp + _time);

        if(harvest) IStrategyAdapterHarvestable(address(adapter)).harvest();
        vm.prank(users.keeper); IStrategyAdapter(address(adapter)).sendReport(type(uint256).max);
        vm.warp(block.timestamp + 7 days);
    }

    function panicAdapter() whenNotPaused whenAdapterActive public {
        vm.prank(users.guardian); IStrategyAdapter(address(adapter)).panic();
    }

    function sendReportPanicked() whenAdapterActive public {
        if(adapter.paused()) {
            vm.prank(users.keeper); IStrategyAdapter(address(adapter)).sendReportPanicked();
        }
    }
}