// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import "forge-std/Test.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { GOA } from "../../src/infra/GOA.sol";
import { MockToken } from "../../src/mocks/MockToken.sol";
import { GoatFarmFactory } from "../../src/infra/GoatFarmFactory.sol";
import { IGoatFarm } from "../../src/interfaces/infra/IGoatFarm.sol";
import { IGoatFarmFactory } from "../../src/interfaces/infra/IGoatFarmFactory.sol";

contract WBTC is ERC20 {
    constructor(address _receiver) ERC20("Wrapped Bitcoin", "WBTC") {
        _mint(_receiver, 1000 * 10 ** decimals());
    }

    function decimals() public pure override returns(uint8) {
        return 8;
    }
}

contract GoatFarmWBTCTest is Test {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////////////////
                                   CONSTANTS
    //////////////////////////////////////////////////////////////////////////*/

    address internal constant TREASURY = 0x7bC668564aF23c2a26cbE50fAeE034B2e034fABc;
    address internal constant USER = 0x80A74Ab94E8a5ca4F1C81ad21e89A450aD8828b0;
    uint256 internal constant DURATION = 1000;
    uint256 private constant FARM_REWARD = 1000 ether;

    /*//////////////////////////////////////////////////////////////////////////
                                   TEST CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/

    IERC20 internal stakedToken;
    IERC20 internal rewardToken;
    IGoatFarm internal farm;
    IGoatFarmFactory internal farmFactory;

    /*//////////////////////////////////////////////////////////////////////////
                                  SET-UP FUNCTION
    //////////////////////////////////////////////////////////////////////////*/

    function setUp() public virtual {
        stakedToken = new WBTC(TREASURY);
        rewardToken = new GOA(TREASURY);
        farmFactory = new GoatFarmFactory();
        farm = IGoatFarm(farmFactory.createFarm(address(stakedToken), address(rewardToken), DURATION));
        farm.setNotifier(TREASURY, true);
        _userDepositWETH(USER, 10 * _unit());
    }

    function _userDepositWETH(address _user, uint256 _amount) internal {
        vm.prank(TREASURY);
        stakedToken.safeTransfer(_user, _amount);
        vm.startPrank(_user);
        stakedToken.approve(address(farm), _amount);
        farm.stake(_amount);
        vm.stopPrank();
    }

    function _notifyRewards(uint256 _amount) internal {
        vm.startPrank(TREASURY);

        rewardToken.approve(address(farm), _amount);
        farm.notifyAmount(_amount);

        vm.stopPrank();
    }

    function _unit() internal view returns (uint256) {
        return 10 ** IERC20Metadata(address(stakedToken)).decimals();
    }

    function test_Deposit() public {
        assertEq(farm.balanceOf(USER), 10 * _unit());
        assertEq(stakedToken.balanceOf(address(farm)), 10 * _unit());
    }

    function test_Withdraw() public {
        vm.prank(USER);
        farm.exit();

        assertEq(farm.balanceOf(USER), 0);
        assertEq(stakedToken.balanceOf(address(farm)), 0);
        assertEq(stakedToken.balanceOf(USER), 10 * _unit());
    }

    function test_Earned() public {
        _notifyRewards(FARM_REWARD);
        vm.warp(block.timestamp + DURATION);
        assertEq(farm.earned(USER), FARM_REWARD);
    }
}
