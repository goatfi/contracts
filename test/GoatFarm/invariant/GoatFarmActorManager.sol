// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import { CommonBase } from "forge-std/Base.sol";
import { StdCheats } from "forge-std/StdCheats.sol";
import { StdUtils } from "forge-std/StdUtils.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IGoatFarm } from "../../../src/interfaces/infra/IGoatFarm.sol";
import { GoatFarmHandler } from "./GoatFarmHandler.sol";

contract GoatFarmActorManager is CommonBase, StdCheats, StdUtils {
    GoatFarmHandler[] handlers;
    IGoatFarm farm;
    IERC20 stakedToken;
    IERC20 rewardToken;

    constructor(GoatFarmHandler[] memory _handlers, IGoatFarm _farm, IERC20 _stakedToken, IERC20 _rewardToken) {
        handlers = _handlers;
        farm = _farm;
        stakedToken = _stakedToken;
        rewardToken = _rewardToken;
    }

    function stake(uint256 _handlerIndex, uint256 _amount) public {
        uint256 index = bound(_handlerIndex, 0, handlers.length - 1);
        if (stakedToken.balanceOf(address(handlers[index])) == 0) return;
        uint256 amount = bound(_amount, 1, stakedToken.balanceOf(address(handlers[index])));
        handlers[index].stake(amount);
    }

    function withdraw(uint256 _handlerIndex, uint256 _amount) public {
        uint256 index = bound(_handlerIndex, 0, handlers.length - 1);
        if (farm.balanceOf(address(handlers[index])) == 0) return;
        uint256 amount = bound(_amount, 1, farm.balanceOf(address(handlers[index])));
        handlers[index].withdraw(amount);
    }

    function getReward(uint256 _handlerIndex) public {
        uint256 index = bound(_handlerIndex, 0, handlers.length - 1);
        handlers[index].getReward();
    }

    function exit(uint256 _handlerIndex) public {
        uint256 index = bound(_handlerIndex, 0, handlers.length - 1);
        if (farm.balanceOf(address(handlers[index])) == 0) return;
        handlers[index].exit();
    }

    function notifyRewards(uint256 _amount) public {
        if (rewardToken.balanceOf(address(handlers[0])) < 1 ether) return;

        uint256 amount = bound(_amount, 1 ether, rewardToken.balanceOf(address(handlers[0])));
        handlers[0].notifyRewards(amount);
    }
}
