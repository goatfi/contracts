// SPDX-License-Identifier: MIT

pragma solidity^0.8.20;

import { CommonBase } from "forge-std/Base.sol";
import { StdCheats } from "forge-std/StdCheats.sol";
import { StdUtils } from "forge-std/StdUtils.sol";
import { TimestampStore } from "test-utils/TimestampStore.sol";
import { GoatRewardPool } from "src/infra/GoatRewardPool.sol";
import { SafeERC20, IERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract RewardPoolHandler is CommonBase, StdCheats, StdUtils {
    using SafeERC20 for IERC20;

    GoatRewardPool rewardPool;
    TimestampStore timestampStore;

    modifier useCurrentTimestamp() {
        vm.warp(timestampStore.currentTimestamp());
        _;
    }

    constructor(GoatRewardPool _rewardPool, TimestampStore _timestampStore) {
        rewardPool = _rewardPool;
        timestampStore = _timestampStore;
    }

    function approve(address _token, address _spender, uint256 _amount) public useCurrentTimestamp {
        IERC20(_token).safeIncreaseAllowance(_spender, _amount);
    }

    function stake(uint256 _amount) public useCurrentTimestamp {
        rewardPool.stake(_amount);
    }

    function withdraw(uint256 _amount) public useCurrentTimestamp {
        rewardPool.withdraw(_amount);
    }

    function exit() public useCurrentTimestamp {
        rewardPool.exit();
    }

    function getReward() public useCurrentTimestamp {
        rewardPool.getReward();
    }

    function transfer(address _to, uint256 _value) public useCurrentTimestamp {
        rewardPool.transfer(_to, _value);
    }

    function notifyRewardAmount(address _reward, uint256 _amount, uint256 _duration) public useCurrentTimestamp {
        rewardPool.notifyRewardAmount(_reward, _amount, _duration);
    }

    function earned(address _reward) public useCurrentTimestamp returns (uint256 rewardEarned) {
        rewardEarned = rewardPool.earned(address(this), _reward);
    }
}
