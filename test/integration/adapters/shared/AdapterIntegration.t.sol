// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Multistrategy } from "src/infra/multistrategy/Multistrategy.sol";
import { StrategyAdapter } from "src/abstracts/StrategyAdapter.sol";
import { Test } from "forge-std/Test.sol";
import { Users } from "../../../utils/Types.sol";
import { IStrategyAdapterHarvestable } from "interfaces/infra/multistrategy/IStrategyAdapterHarvestable.sol";

abstract contract AdapterIntegration is Test {
    Users internal users;
    Multistrategy multistrategy;
    StrategyAdapter adapter;

    address public asset;
    uint256 public depositLimit;
    uint256 public minDeposit;
    bool public harvest;

    function setUp() public virtual {
        users = Users({
            owner: createUser("Owner"),
            keeper: createUser("Keeper"),
            guardian: createUser("Guardian"),
            feeRecipient: createUser("FeeRecipient"),
            alice: createUser("Alice"),
            bob: createUser("Bob")
        });
    }

    function createUser(string memory name) internal returns (address payable) {
        address payable user = payable(makeAddr(name));
        vm.deal({account: user, newBalance: 100 ether});
        vm.label({ account: address(user), newLabel: name });
        return user;
    }

    function createMultistrategy(address _asset, uint256 _depositLimit) public {
        vm.prank(users.owner); multistrategy = new Multistrategy({
            _asset: _asset,
            _manager: users.keeper,
            _protocolFeeRecipient: users.feeRecipient,
            _name: "",
            _symbol: ""
        });

        vm.prank(users.owner); multistrategy.enableGuardian(users.guardian);
        vm.prank(users.owner); multistrategy.setDepositLimit(_depositLimit);
        vm.prank(users.owner); multistrategy.setPerformanceFee(1000);

        vm.label({ account: address(multistrategy), newLabel: "Multistrategy" });
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     ACTIONS
    //////////////////////////////////////////////////////////////////////////*/

    function addAdapter(StrategyAdapter _adapter) public {
        vm.prank(users.owner); multistrategy.addStrategy(address(_adapter), 10_000, 0, type(uint256).max);
    }

    function setDebtRatio(StrategyAdapter _adapter, uint256 _debtRatio) public {
        vm.prank(users.keeper); multistrategy.setStrategyDebtRatio(address(_adapter), _debtRatio);
        vm.prank(users.keeper); _adapter.requestCredit();
        vm.prank(users.keeper); _adapter.sendReport(type(uint256).max);
    }

    function requestCredit(StrategyAdapter _adapter) public {
        vm.prank(users.keeper); _adapter.requestCredit();
    }

    function deposit(uint256 _amount) public {
        deal(asset, users.bob, _amount);
        vm.prank(users.bob); IERC20(asset).approve(address(multistrategy), _amount);
        vm.prank(users.bob); multistrategy.deposit(_amount, users.bob);
    }

    function withdraw(uint256 _amount) public {
        vm.prank(users.bob); multistrategy.withdraw(_amount, users.bob, users.bob);
    }

    function withdrawAll() public {
        uint256 balance = multistrategy.balanceOf(users.bob);
        if(balance > 0) {
            vm.prank(users.bob); multistrategy.redeem(balance, users.bob, users.bob);
        }
    }

    function earnYield(uint256 _time) public {
        uint256 availableCredit = multistrategy.creditAvailable(address(adapter));
        if(availableCredit > 1) {
            vm.prank(users.keeper); adapter.requestCredit();
        }
        vm.warp(block.timestamp + _time);

        if(harvest) IStrategyAdapterHarvestable(address(adapter)).harvest();
        vm.prank(users.keeper); adapter.sendReport(type(uint256).max);
        vm.warp(block.timestamp + 7 days);
    }

    function retireAdapter(StrategyAdapter _adapter) public {
        vm.prank(users.owner); multistrategy.retireStrategy(address(_adapter));
    }

    function removeAdapter(StrategyAdapter _adapter) public {
        vm.prank(users.owner); multistrategy.removeStrategy(address(_adapter));
    }

    function panicAdapter(StrategyAdapter _adapter) public {
        vm.prank(users.guardian); _adapter.panic();
    }

    function sendReportPanicked(StrategyAdapter _adapter) public {
        vm.prank(users.keeper); _adapter.sendReportPanicked();
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     TESTS
    //////////////////////////////////////////////////////////////////////////*/

    function adapterLifeCycle(uint256 _depositAmount, uint256 _withdrawAmount, uint256 _yieldTime, uint256 _debtRatio) public {
        deposit(_depositAmount);
        addAdapter(adapter);
        requestCredit(adapter);
        earnYield(_yieldTime);
        setDebtRatio(adapter, _debtRatio);
        withdraw(_withdrawAmount);
        requestCredit(adapter);
        withdraw(1);
        retireAdapter(adapter);
        withdrawAll();
    }

    function adapterPanicProcedure(uint256 _depositAmount, uint256 _withdrawAmount, uint256 _yieldTime, uint256 _debtRatio) public {
        deposit(_depositAmount);
        addAdapter(adapter);
        requestCredit(adapter);
        earnYield(_yieldTime);
        setDebtRatio(adapter, _debtRatio);
        withdraw(_withdrawAmount);

        retireAdapter(adapter);
        panicAdapter(adapter);
        sendReportPanicked(adapter);
    }

    function adapterMixer() public {
        uint256 runs = vm.randomUint(8);

        deposit(minDeposit);
        addAdapter(adapter);
        requestCredit(adapter);

        for (uint16 i = 0; i < runs; ++i) {
            // Maybe deposit something
            uint256 depositAmount = vm.randomUint(256);
            depositAmount = bound(depositAmount, 0, multistrategy.depositLimit() - multistrategy.totalAssets());
            deposit(depositAmount);

            // Rebalance
            uint256 debtRatio = vm.randomUint(256);
            debtRatio = bound(debtRatio, 0, 10_000);
            setDebtRatio(adapter, debtRatio);

            // Earn yield
            uint256 yieldTime = vm.randomUint(256);
            yieldTime = bound(yieldTime, 1 hours, 30 days);
            earnYield(yieldTime);

            // Maybe withdraw
            uint256 withdrawAmount = vm.randomUint(256);
            withdrawAmount = bound(withdrawAmount, 0, multistrategy.maxWithdraw(users.bob));
            withdraw(withdrawAmount);
        }

        retireAdapter(adapter);
        withdrawAll();
    }
}