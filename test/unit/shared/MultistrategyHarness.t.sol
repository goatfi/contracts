// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.20 <0.9.0;

import { Base_Test } from "../../Base.t.sol";
import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import { IStrategyAdapterMock } from "../../shared/TestInterfaces.sol";

contract MultistrategyHarness_Unit_Shared_Test is Base_Test {
    function setUp() public virtual override {
        Base_Test.setUp();
        
        deployMultistrategyHarness();
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
        dai.approve(address(multistrategyHarness), _amount);
        IERC4626(address(multistrategyHarness)).deposit(_amount, _user);

        // Switch back the caller to the owner, as stated in the setup funciton
        swapCaller(users.owner);
    }
}