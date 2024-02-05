// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import { CommonBase } from "forge-std/Base.sol";
import { StdCheats } from "forge-std/StdCheats.sol";
import { StdUtils } from "forge-std/StdUtils.sol";
import { TimestampStore } from "../../../stores/TimestampStore.sol";
import { GoatFeeBatch } from "src/infra/GoatFeeBatch.sol";
import { WETH } from "lib/common/weth/WETH.sol";

contract FeeBatchHandler is CommonBase, StdCheats, StdUtils {
    GoatFeeBatch feeBatch;
    WETH weth;
    TimestampStore timestampStore;

    uint256 public revenueGenerated;

    //Adds 10 seconds between calls
    modifier useCurrentTimestamp() {
        timestampStore.increaseCurrentTimestamp(10);
        vm.warp(timestampStore.currentTimestamp());
        _;
    }

    constructor(GoatFeeBatch _feeBatch, WETH _weth, TimestampStore _timestampStore) {
        feeBatch = _feeBatch;
        weth = _weth;
        timestampStore = _timestampStore;
        revenueGenerated = 0;
    }

    function generateRevenue(uint256 _amount) public useCurrentTimestamp {
        deal(address(this), _amount);
        weth.deposit{value: _amount}();
        weth.transfer(address(feeBatch), _amount);
        revenueGenerated += _amount;
    }

    function harvest() public useCurrentTimestamp {
        feeBatch.harvest();
    }

    function setHarvesterConfig(address _harvester, uint256 _harvesterMax) public {
        feeBatch.setHarvesterConfig(_harvester, _harvesterMax);
    }

    function setSendHarvesterGas(bool _sendGas) public {
        feeBatch.setSendHarvesterGas(_sendGas);
    }

    function setTreasuryFee(uint256 _treasuryFee) public {
        feeBatch.setTreasuryFee(_treasuryFee);
    }

    function setDuration(uint256 _duration) public {
        feeBatch.setDuration(_duration);
    }
}
