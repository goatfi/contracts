// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.20 <0.9.0;

import { Base_Test } from "../../Base.t.sol";
import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import { StrategyAdapterMock } from "../../mocks/StrategyAdapterMock.sol";
import { IERC20Mock } from "interfaces/common/IERC20Mock.sol";

contract Multistrategy_Integration_Shared_Test is Base_Test {

    IERC20Mock asset;
    
    function setUp() public virtual override {
        Base_Test.setUp();
        
        deployMultistrategy();
        transferMultistrategyOwnershipToOwner();

        swapCaller(users.owner);

        asset = IERC20Mock(IERC4626(address(multistrategy)).asset());
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
        asset.approve(address(multistrategy), _amount);
        IERC4626(address(multistrategy)).deposit(_amount, _user);

        // Switch back the caller to the owner, as stated in the setup function
        swapCaller(users.owner);
    }

    function triggerApprove(address _caller, address _target, uint256 _amount) internal {
        swapCaller(_caller); 
        asset.approve(_target, _amount);
        swapCaller(users.owner);
    }

    function mintAsset(address _receiver, uint256 _amount) internal {
        asset.mint(_receiver, _amount);
    }
}