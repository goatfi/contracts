// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.20 <0.9.0;

import { Base_Test } from "../../Base.t.sol";
import { IStrategyAdapterMock } from "../../shared/TestInterfaces.sol";

contract Multistrategy_Unit_Shared_Test is Base_Test {
    function setUp() public virtual override {
        Base_Test.setUp();
        
        deployMultistrategy();
        transferMultistrategyOwnershipToOwner();

        swapCaller(users.owner);
    }

    function triggerStrategyGain(address _strategy, uint256 _amount) internal {
        IStrategyAdapterMock(_strategy).earn(_amount);
    }

    function triggerStrategyLoss(address _strategy, uint256 _amount) internal {
        IStrategyAdapterMock(_strategy).lose(_amount);
    }

    function triggerUserDeposit(address _user, uint256 _amount) internal {
        dai.mint(_user, _amount);
        
        swapCaller(_user);
        dai.approve(address(multistrategy), _amount);
        multistrategy.deposit(_amount, _user);

        // Switch back the caller to the owner, as stated in the setup funciton
        swapCaller(users.owner);
    }
}