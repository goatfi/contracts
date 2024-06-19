// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.20 <0.9.0;

import { Base_Test } from "../../Base.t.sol";

interface IOwnable {
    function transferOwnership(address newOwner) external;
}

interface IStrategyAdapterMock {
    function earn(uint256 _amount) external;
    function lose(uint256 _amount) external;
}

contract MultistrategyHarness_Integration_Shared_Test is Base_Test {
    function setUp() public virtual override {
        Base_Test.setUp();
        
        deployMultistrategyHarness();
        transferMultistrategyOwnershipToOwner();

        vm.startPrank({ msgSender: users.owner });
    }

    function transferMultistrategyOwnershipToOwner() internal {
        IOwnable(address(multistrategyHarness)).transferOwnership({ newOwner: users.owner });
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
        multistrategyHarness.deposit(_amount);

        // Switch back the caller to the owner, as stated in the setup funciton
        swapCaller(users.owner);
    }
}