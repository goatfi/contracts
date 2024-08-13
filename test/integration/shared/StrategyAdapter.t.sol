// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.20 <0.9.0;

import { Base_Test } from "../../Base.t.sol";
import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import { IStrategyAdapter } from "interfaces/infra/multistrategy/IStrategyAdapter.sol";
import { IOwnable } from "../../shared/TestInterfaces.sol";
import { IERC20Mock } from "interfaces/common/IERC20Mock.sol";

contract StrategyAdapter_Integration_Shared_Test is Base_Test {

    IStrategyAdapter strategy;
    IERC20Mock asset;

    function setUp() public virtual override {
        Base_Test.setUp();

        deployMultistrategy();
        transferMultistrategyOwnershipToOwner();
        strategy = IStrategyAdapter(deployMockStrategyAdapter(address(multistrategy), IERC4626(address(multistrategy)).asset()));
        transferStrategyAdapterOwnershipToOwner();

        swapCaller(users.owner);

        asset = IERC20Mock(IERC4626(address(multistrategy)).asset());
    }

    function requestCredit(address _strategy, uint256 _amount) internal {
        // Add the strategy to the multistrategy
        multistrategy.addStrategy(address(_strategy), 10_000, 0, 100_000 ether);
        asset.mint(users.bob, _amount);
        
        swapCaller(users.bob);
        asset.approve(address(multistrategy), _amount);
        IERC4626(address(multistrategy)).deposit(_amount, users.bob);

        // Switch back the caller to the owner, as stated in the setup function
        swapCaller(users.owner);

        IStrategyAdapter(_strategy).requestCredit();
    }

    function triggerUserDeposit(address _user, uint256 _amount) internal {
        asset.mint(_user, _amount);
        
        swapCaller(_user);
        asset.approve(address(multistrategy), _amount);
        IERC4626(address(multistrategy)).deposit(_amount, _user);

        // Switch back the caller to the owner, as stated in the setup function
        swapCaller(users.owner);
    }

    function transferStrategyAdapterOwnershipToOwner() internal {
        IOwnable(address(strategy)).transferOwnership(users.owner);
    }
}