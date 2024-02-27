// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import { CommonBase } from "forge-std/Base.sol";
import { StdCheats } from "forge-std/StdCheats.sol";
import { StdUtils } from "forge-std/StdUtils.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { TimestampStore } from "test-utils/TimestampStore.sol";
import { RewardPoolHandler } from "./RewardPoolHandler.sol";
import { GoatRewardPool } from "src/infra/GoatRewardPool.sol";

contract RewardPoolActorManager is CommonBase, StdCheats, StdUtils {
    RewardPoolHandler[] handlers;
    GoatRewardPool rewardPool;
    TimestampStore timestampStore;
    IERC20 goa;
    IERC20 weth;
    address treasury;

    bool rewardHasBeenAdded;

    /// @dev Handlers index => value
    mapping(uint256 => uint256) public stakedAmount;
    mapping(uint256 => uint256) public rewardsClaimed;
    uint256 public rewardsDistributed;

    constructor(RewardPoolHandler[] memory _handlers, GoatRewardPool _rewardPool, TimestampStore _timestampStore, IERC20 _goa, IERC20 _weth, address _treasury) {
        handlers = _handlers;
        rewardPool = _rewardPool;
        timestampStore = _timestampStore;
        goa = _goa;
        weth = _weth;
        treasury = _treasury;
    }

    //Increase time by 60s
    modifier incrementTime() {
        timestampStore.increaseCurrentTimestamp(60);
        _;
    }

    /// @dev Function to give GOA to a handler, doesn't actually buy them.
    function buyGOA(uint256 _handlerIndex, uint256 _amount) public incrementTime {
        uint256 index = bound(_handlerIndex, 0, handlers.length - 1);
        uint256 amount = bound(_amount, 0, goa.balanceOf(treasury));
        goa.transferFrom(treasury, address(handlers[index]), amount);
    }

    /// @dev Function to reduce GOA balance of a handler, doesn't actually sell them.
    function sellGOA(uint256 _handlerIndex, uint256 _amount) public incrementTime {
        uint256 index = bound(_handlerIndex, 0, handlers.length - 1);
        uint256 amount = bound(_amount, 0, goa.balanceOf(address(handlers[index])));
        goa.transferFrom(address(handlers[index]), treasury, amount);
    }

    function stake(uint256 _handlerIndex, uint256 _amount) public incrementTime {
        uint256 index = bound(_handlerIndex, 0, handlers.length - 1);
        uint256 amount = bound(_amount, 0, goa.balanceOf(address(handlers[index])));

        handlers[index].approve(address(goa), address(rewardPool), amount);
        handlers[index].stake(amount);

        stakedAmount[index] += amount;
    }

    function withdraw(uint256 _handlerIndex, uint256 _amount) public incrementTime {
        uint256 index = bound(_handlerIndex, 0, handlers.length - 1);
        uint256 amount = bound(_amount, 0, rewardPool.balanceOf(address(handlers[index])));
        handlers[index].withdraw(amount);

        stakedAmount[index] -= amount;
    }

    function exit(uint256 _handlerIndex) public incrementTime {
        uint256 index = bound(_handlerIndex, 0, handlers.length - 1);
        uint256 earned = handlers[index].earned(address(weth));
        handlers[index].exit();

        stakedAmount[index] = 0;
        rewardsClaimed[index] += earned;
    }

    function getReward(uint256 _handlerIndex) public incrementTime {
        uint256 index = bound(_handlerIndex, 0, handlers.length - 1);
        uint256 earned = handlers[index].earned(address(weth));
        handlers[index].getReward();

        rewardsClaimed[index] += earned;
    }

    function transfer(uint256 _handlerIndex, uint8 _to, uint256 _value) public incrementTime {
        uint256 index = bound(_handlerIndex, 0, handlers.length - 1);
        if (rewardPool.balanceOf(address(handlers[index])) == 0) return;
        uint256 to = bound(_to, 0, handlers.length - 1);
        uint256 value = bound(_value, 1, rewardPool.balanceOf(address(handlers[index])));

        handlers[index].transfer(address(handlers[to]), value);

        stakedAmount[index] -= value;
        stakedAmount[to] += value;
    }

    function notifyRewardAmount(uint256 _handlerIndex, uint256 _amount, uint256 _duration) public incrementTime {
        uint256 index = bound(_handlerIndex, 0, handlers.length - 1);
        if (index != 0) return;
        if (weth.balanceOf(address(handlers[index])) == 0) return;
        uint256 duration = bound(_duration, 1 hours, 365 days);
        uint256 amount = bound(_amount, 1, weth.balanceOf(address(handlers[index])));
        handlers[index].approve(address(weth), address(rewardPool), amount);
        handlers[index].notifyRewardAmount(address(weth), amount, duration);
        rewardHasBeenAdded = true;
        rewardsDistributed += amount;
    }
}
