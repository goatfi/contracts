// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import "forge-std/Test.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ERC20Mock } from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import { GoatFarmFactory } from "src/infra/GoatFarmFactory.sol";

contract GoatFarmFactoryTest is Test {
    
    IERC20 private stakedToken;
    IERC20 private rewardToken;
    GoatFarmFactory private farmFactory;

    function setUp() public {
        stakedToken = IERC20(new ERC20Mock());
        rewardToken = IERC20(new ERC20Mock());
        farmFactory = new GoatFarmFactory();
    }

    function test_createFarm() public {
        address goatFarm = farmFactory.createFarm(address(stakedToken), address(rewardToken), 0);
        assertTrue(goatFarm != address(0));
    }
}
