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

    constructor(Multistrategy _multistrategy, StrategyAdapter _adapter, Users memory _users, bool _harvest) {
        multistrategy = _multistrategy;
        adapter = _adapter;
        users = _users;
        harvest = _harvest;
        asset = multistrategy.asset();
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     ACTIONS
    //////////////////////////////////////////////////////////////////////////*/

    function addAdapter() public {
        MStrat.StrategyParams memory strategyParams = IMultistrategyManageable(address(multistrategy)).getStrategyParameters(address(adapter));
        if(strategyParams.activation == 0) {
            vm.prank(users.owner); IMultistrategyManageable(address(multistrategy)).addStrategy(address(adapter), 10_000, 0, type(uint256).max);
        }
    }

    function retireAdapter() public {
        vm.prank(users.owner); IMultistrategyManageable(address(multistrategy)).retireStrategy(address(adapter));
    }

    function removeAdapter() public {
        MStrat.StrategyParams memory strategyParams = IMultistrategyManageable(address(multistrategy)).getStrategyParameters(address(adapter));
        if(strategyParams.debtRatio == 0) {
            if(strategyParams.totalDebt > 0 ) {
                if(!adapter.paused()) IStrategyAdapter(address(adapter)).sendReport(type(uint256).max);
            }
            vm.prank(users.owner); IMultistrategyManageable(address(multistrategy)).removeStrategy(address(adapter));
        }
    }

    function setDebtRatio(uint256 _debtRatio) public {
        if(adapter.paused()) return;

        _debtRatio = bound(_debtRatio, 0, 10_000);

        vm.prank(users.keeper); IMultistrategyManageable(address(multistrategy)).setStrategyDebtRatio(address(adapter), _debtRatio);
        vm.prank(users.keeper); IStrategyAdapter(address(adapter)).requestCredit();
        vm.prank(users.keeper); IStrategyAdapter(address(adapter)).sendReport(type(uint256).max);
    }

    function requestCredit() public {
        if(adapter.paused()) return;
        
        vm.prank(users.keeper); IStrategyAdapter(address(adapter)).requestCredit();
    }

    function deposit(uint256 _amount) public {
        if(adapter.paused()) return;
        _amount = bound(_amount, 0, multistrategy.depositLimit() - multistrategy.totalAssets());

        deal(asset, users.bob, _amount);
        vm.prank(users.bob); IERC20(asset).approve(address(multistrategy), _amount);
        vm.prank(users.bob); IERC4626(address(multistrategy)).deposit(_amount, users.bob);
    }

    function withdraw(uint256 _amount) public {
        if(adapter.paused()) return;
        _amount = bound(_amount, 1, IERC4626(address(multistrategy)).maxWithdraw(users.bob));

        vm.prank(users.bob); IERC4626(address(multistrategy)).withdraw(_amount, users.bob, users.bob);
    }

    function withdrawAll() public {
        if(adapter.paused()) return;

        uint256 balance = IERC4626(address(multistrategy)).balanceOf(users.bob);
        if(balance > 0) {
            vm.prank(users.bob); IERC4626(address(multistrategy)).redeem(balance, users.bob, users.bob);
        }
    }

    function earnYield(uint256 _time) public virtual {
        if(adapter.paused()) return;

        _time = bound(_time, 1 hours, 30 days);

        vm.warp(block.timestamp + _time);
        if(harvest) IStrategyAdapterHarvestable(address(adapter)).harvest();
        vm.prank(users.keeper); IStrategyAdapter(address(adapter)).sendReport(type(uint256).max);
        vm.warp(block.timestamp + 7 days);
    }

    function panicAdapter() public {
        if(adapter.paused()) return;

        vm.prank(users.guardian); IStrategyAdapter(address(adapter)).panic();
    }

    function sendReportPanicked() public {
        if(adapter.paused()) {
            vm.prank(users.keeper); IStrategyAdapter(address(adapter)).sendReportPanicked();
        }
    }
}