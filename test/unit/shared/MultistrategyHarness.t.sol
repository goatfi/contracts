// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.20 <0.9.0;

import { Base_Test } from "../../Base.t.sol";
import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import { StrategyAdapterMock } from "../../mocks/StrategyAdapterMock.sol";
import { IERC20Mock } from "interfaces/common/IERC20Mock.sol";

contract MultistrategyHarness_Unit_Shared_Test is Base_Test {

    IERC20Mock asset;
    
    function setUp() public virtual override {
        Base_Test.setUp();
        
        deployMultistrategyHarness();
        transferMultistrategyOwnershipToOwner();

        swapCaller(users.owner);

        asset = IERC20Mock(IERC4626(address(multistrategyHarness)).asset());
    }

    function triggerStrategyGain(StrategyAdapterMock _strategy, uint256 _amount) internal {
        _strategy.earn(_amount);
    }

    function triggerStrategyLoss(StrategyAdapterMock _strategy, uint256 _amount) internal {
        _strategy.lose(_amount);
    }

    function triggerUserDeposit(address _user, uint256 _amount) internal {
        asset.mint(_user, _amount);
        
        swapCaller(_user);
        asset.approve(address(multistrategyHarness), _amount);
        IERC4626(address(multistrategyHarness)).deposit(_amount, _user);

        // Switch back the caller to the owner, as stated in the setup funciton
        swapCaller(users.owner);
    }
}