// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import { CommonBase } from "forge-std/Base.sol";
import { StdCheats } from "forge-std/StdCheats.sol";
import { StdUtils } from "forge-std/StdUtils.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { FeeBatchHandler } from "./FeeBatchHandler.sol";
import { GoatFeeBatch} from "src/infra/GoatFeeBatch.sol";

contract FeeBatchActorManager is CommonBase, StdCheats, StdUtils {
    FeeBatchHandler[] handlers;
    GoatFeeBatch feeBatch;
    IERC20 weth;
    address harvester;

    constructor(FeeBatchHandler[] memory _handlers, GoatFeeBatch _feeBatch, IERC20 _weth, address _harvester) {
        handlers = _handlers;
        feeBatch = _feeBatch;
        weth = _weth;
        harvester = _harvester;
    }

    function generateRevenue(uint256 _handlerIndex, uint256 _amount) public {
        uint256 index = bound(_handlerIndex, 0, handlers.length - 1);
        uint256 amount = bound(_amount, 0, 120_000_000 ether);
        handlers[index].generateRevenue(amount);
    }

    function harvest(uint256 _handlerIndex) public {
        uint256 index = bound(_handlerIndex, 0, handlers.length - 1);
        handlers[index].harvest();
    }

    function setHarvesterConfig(uint256 _handlerIndex, uint256 _harvesterMax) public {
        uint256 index = bound(_handlerIndex, 0, handlers.length - 1);
        if(index != 0) return;
        handlers[index].setHarvesterConfig(harvester, _harvesterMax);
    }

    function setSendHarvestGas(uint256 _handlerIndex, bool _sendGas) public {
        uint256 index = bound(_handlerIndex, 0, handlers.length - 1);
        if(index != 0) return;
        handlers[index].setSendHarvesterGas(_sendGas);
    }

    function setTreasuryFee(uint256 _handlerIndex, uint256 _treasuryFee) public {
        uint256 index = bound(_handlerIndex, 0, handlers.length - 1);
        uint256 treasuryFee = bound(_treasuryFee, 0, 499);
        if(index != 0) return;
        handlers[index].setTreasuryFee(treasuryFee);
    }

    function setDuration(uint256 _handlerIndex, uint256 _duration) public {
        uint256 index = bound(_handlerIndex, 0, handlers.length - 1);
        uint256 duration = bound(_duration, 1 hours, 365 days);
        if(index != 0) return;
        handlers[index].setDuration(duration);
    }
}
