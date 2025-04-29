// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Test } from "forge-std/Test.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Multistrategy } from "src/infra/multistrategy/Multistrategy.sol";
import { StrategyAdapter } from "src/abstracts/StrategyAdapter.sol";
import { Users } from "../../utils/Types.sol";
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

    modifier whenNoOutstandingDebt() {
        MStrat.StrategyParams memory strategyParams = multistrategy.getStrategyParameters(address(adapter));
        vm.assume(strategyParams.totalDebt == 0);
        _; 
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     ACTIONS
    //////////////////////////////////////////////////////////////////////////*/

    function setDebtRatio(uint256 _debtRatio) public {
        _debtRatio = bound(_debtRatio, 0, 10_000);

        vm.warp(block.timestamp + 10 minutes);

        vm.prank(users.keeper); multistrategy.setStrategyDebtRatio(address(adapter), _debtRatio);
        vm.prank(users.keeper); adapter.requestCredit();
        vm.prank(users.keeper); adapter.sendReport(type(uint256).max);
    }

    function requestCredit() public {
        uint256 availableCredit = multistrategy.creditAvailable(address(adapter));
        if(availableCredit > 1) {
            vm.prank(users.keeper); adapter.requestCredit();
        }
    }

    function deposit(uint256 _amount) public {
        if(multistrategy.totalAssets() >= multistrategy.depositLimit()) return;
        uint256 maxDeposit = multistrategy.depositLimit() - multistrategy.totalAssets();
        if(maxDeposit == 0) return;

        _amount = bound(_amount, 1, maxDeposit);
        ghost_deposited += _amount;

        deal(asset, users.bob, _amount);
        vm.prank(users.bob); IERC20(asset).approve(address(multistrategy), _amount);
        vm.prank(users.bob); multistrategy.deposit(_amount, users.bob);
    }

    function withdraw(uint256 _amount) public {
        uint256 maxWithdraw = multistrategy.maxWithdraw(users.bob);
        if(maxWithdraw == 0) return;

        _amount = bound(_amount, 1, maxWithdraw);
        ghost_withdrawn += _amount;

        vm.warp(block.timestamp + 10 minutes);
        vm.prank(users.bob); multistrategy.withdraw(_amount, users.bob, users.bob);
    }

    function withdrawAll() public {
        uint256 balance = multistrategy.balanceOf(users.bob);
        if(balance > 0) {
            vm.warp(block.timestamp + 10 minutes);
            vm.prank(users.bob); multistrategy.redeem(balance, users.bob, users.bob);
        }
    }

    function earnYield(uint256 _time) public {
        _time = bound(_time, 1 days, 30 days);

        ghost_yieldTime += _time;
        uint256 availableCredit = multistrategy.creditAvailable(address(adapter));
        if(availableCredit > 1) {
            vm.prank(users.keeper); adapter.requestCredit();
        }
        vm.warp(block.timestamp + _time);

        if(harvest) IStrategyAdapterHarvestable(address(adapter)).harvest();
        vm.prank(users.keeper); adapter.sendReport(type(uint256).max);
        vm.warp(block.timestamp + 7 days);
    }
}