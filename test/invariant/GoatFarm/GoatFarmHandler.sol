// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import { CommonBase } from "forge-std/Base.sol";
import { StdCheats } from "forge-std/StdCheats.sol";
import { StdUtils } from "forge-std/StdUtils.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IGoatFarm } from "interfaces/infra/IGoatFarm.sol";
import { TimestampStore } from "test-utils/TimestampStore.sol";

contract GoatFarmHandler is CommonBase, StdCheats, StdUtils {
    IGoatFarm farm;
    IERC20 stakedToken;
    IERC20 rewardToken;
    TimestampStore timestampStore;

    //Adds 10 seconds between calls
    modifier useCurrentTimestamp() {
        timestampStore.increaseCurrentTimestamp(10);
        vm.warp(timestampStore.currentTimestamp());
        _;
    }

    constructor(IGoatFarm _farm, IERC20 _stakedToken, IERC20 _rewardToken, TimestampStore _timestampStore) {
        farm = _farm;
        stakedToken = _stakedToken;
        rewardToken = _rewardToken;
        timestampStore = _timestampStore;
    }

    function stake(uint256 _amount) public useCurrentTimestamp {
        stakedToken.approve(address(farm), _amount);
        farm.stake(_amount);
    }

    function withdraw(uint256 _amount) public useCurrentTimestamp {
        farm.withdraw(_amount);
    }

    function getReward() public useCurrentTimestamp {
        farm.getReward();
    }

    function exit() public useCurrentTimestamp {
        farm.exit();
    }

    function notifyRewards(uint256 _amount) public useCurrentTimestamp {
        rewardToken.approve(address(farm), _amount);
        farm.notifyAmount(_amount);
    }
}
