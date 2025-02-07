// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import { Multistrategy } from "src/infra/multistrategy/Multistrategy.sol";
import { StrategyAdapter } from "src/abstracts/StrategyAdapter.sol";
import { Test } from "forge-std/Test.sol";
import { Users } from "../../../utils/Types.sol";
import { IMultistrategyManageable } from "interfaces/infra/multistrategy/IMultistrategyManageable.sol";
import { IStrategyAdapter } from "interfaces/infra/multistrategy/IStrategyAdapter.sol";
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

    function addAdapter(address _adapter) public {
        vm.prank(users.owner); IMultistrategyManageable(address(multistrategy)).addStrategy(_adapter, 10_000, 0, type(uint256).max);
    }

    function setDebtRatio(address _adapter, uint256 _debtRatio) public {
        vm.prank(users.keeper); IMultistrategyManageable(address(multistrategy)).setStrategyDebtRatio(_adapter, _debtRatio);
        vm.prank(users.keeper); IStrategyAdapter(_adapter).requestCredit();
        vm.prank(users.keeper); IStrategyAdapter(_adapter).sendReport(type(uint256).max);
    }

    function requestCredit(address _adapter) public {
        vm.prank(users.keeper); IStrategyAdapter(_adapter).requestCredit();
    }

    function deposit(uint256 _amount) public {
        deal(asset, users.bob, _amount);
        vm.prank(users.bob); IERC20(asset).approve(address(multistrategy), _amount);
        vm.prank(users.bob); IERC4626(address(multistrategy)).deposit(_amount, users.bob);
    }

    function withdraw(uint256 _amount) public {
        vm.prank(users.bob); IERC4626(address(multistrategy)).withdraw(_amount, users.bob, users.bob);
    }

    function withdrawAll() public {
        uint256 balance = IERC4626(address(multistrategy)).balanceOf(users.bob);
        if(balance > 0) {
            vm.prank(users.bob); IERC4626(address(multistrategy)).redeem(balance, users.bob, users.bob);
        }
    }

    function earnYield(address _adapter, uint256 _time) public virtual {
        vm.warp(block.timestamp + _time);
        if(harvest) IStrategyAdapterHarvestable(_adapter).harvest();
        vm.prank(users.keeper); IStrategyAdapter(_adapter).sendReport(type(uint256).max);
        vm.warp(block.timestamp + 7 days);
    }

    function retireAdapter(address _adapter) public {
        vm.prank(users.owner); IMultistrategyManageable(address(multistrategy)).retireStrategy(_adapter);
    }

    function removeAdapter(address _adapter) public {
        vm.prank(users.owner); IMultistrategyManageable(address(multistrategy)).removeStrategy(_adapter);
    }

    function panicAdapter(address _adapter) public {
        vm.prank(users.guardian); IStrategyAdapter(_adapter).panic();
    }

    function sendReportPanicked(address _adapter) public {
        vm.prank(users.keeper); IStrategyAdapter(_adapter).sendReportPanicked();
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     TESTS
    //////////////////////////////////////////////////////////////////////////*/

    function adapterLifeCycle(uint256 _depositAmount, uint256 _withdrawAmount, uint256 _yieldTime, uint256 _debtRatio) public {
        deposit(_depositAmount);
        addAdapter(address(adapter));
        requestCredit(address(adapter));
        earnYield(address(adapter), _yieldTime);
        setDebtRatio(address(adapter), _debtRatio);
        withdraw(_withdrawAmount);
        requestCredit(address(adapter));
        withdraw(1);
        retireAdapter(address(adapter));
        withdrawAll();
    }

    function adapterPanicProcedure(uint256 _depositAmount, uint256 _withdrawAmount, uint256 _yieldTime, uint256 _debtRatio) public {
        deposit(_depositAmount);
        addAdapter(address(adapter));
        requestCredit(address(adapter));
        earnYield(address(adapter), _yieldTime);
        setDebtRatio(address(adapter), _debtRatio);
        withdraw(_withdrawAmount);

        retireAdapter(address(adapter));
        panicAdapter(address(adapter));
        sendReportPanicked(address(adapter));
    }

    function adapterMixer() public {
        uint256 runs = vm.randomUint(8);

        deposit(minDeposit);
        addAdapter(address(adapter));
        requestCredit(address(adapter));

        for (uint16 i = 0; i < runs; ++i) {
            // Maybe deposit something
            uint256 depositAmount = vm.randomUint(256);
            depositAmount = bound(depositAmount, 0, multistrategy.depositLimit() - multistrategy.totalAssets());
            deposit(depositAmount);

            // Rebalance
            uint256 debtRatio = vm.randomUint(256);
            debtRatio = bound(debtRatio, 0, 10_000);
            setDebtRatio(address(adapter), debtRatio);

            // Earn yield
            uint256 yieldTime = vm.randomUint(256);
            yieldTime = bound(yieldTime, 1 hours, 30 days);
            earnYield(address(adapter), yieldTime);

            // Maybe withdraw
            uint256 withdrawAmount = vm.randomUint(256);
            withdrawAmount = bound(withdrawAmount, 0, IERC4626(address(multistrategy)).maxWithdraw(users.bob));
            withdraw(withdrawAmount);
        }

        retireAdapter(address(adapter));
        withdrawAll();
    }
}