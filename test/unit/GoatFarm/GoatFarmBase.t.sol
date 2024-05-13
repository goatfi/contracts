// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import "forge-std/Test.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { GOA } from "src/infra/GOA.sol";
import { MockToken } from "src/mocks/MockToken.sol";
import { GoatFarmFactory } from "src/infra/GoatFarmFactory.sol";
import { IGoatFarm } from "src/interfaces/infra/IGoatFarm.sol";
import { IGoatFarmFactory } from "src/interfaces/infra/IGoatFarmFactory.sol";

contract GoatFarmTestBase is Test {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////////////////
                                   CONSTANTS
    //////////////////////////////////////////////////////////////////////////*/

    address internal constant TREASURY = 0x7bC668564aF23c2a26cbE50fAeE034B2e034fABc;
    address internal constant USER = 0x80A74Ab94E8a5ca4F1C81ad21e89A450aD8828b0;
    uint256 internal constant DURATION = 1000;

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
        stakedToken = new MockToken(100 ether, "Wrapped Ethereum", "WETH");
        rewardToken = new GOA(TREASURY);
        farmFactory = new GoatFarmFactory();
        farm = IGoatFarm(farmFactory.createFarm(address(stakedToken), address(rewardToken), DURATION));
        farm.setNotifier(TREASURY, true);
    }

    function _userDepositWETH(address _user, uint256 _amount) internal {
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
}
