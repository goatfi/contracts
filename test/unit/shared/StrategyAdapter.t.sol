// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.20 <0.9.0;

import { Base_Test } from "../../Base.t.sol";
import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import { IStrategyAdapter } from "interfaces/infra/multistrategy/IStrategyAdapter.sol";
import { IOwnable } from "../../shared/TestInterfaces.sol";

contract StrategyAdapter_Unit_Shared_Test is Base_Test {

    IStrategyAdapter strategy;

    function setUp() public virtual override {
        Base_Test.setUp();

        deployMultistrategy();
        transferMultistrategyOwnershipToOwner();
        strategy = IStrategyAdapter(deployMockStrategyAdapter(address(multistrategy), IERC4626(address(multistrategy)).asset()));
        transferStrategyAdapterOwnershipToOwner();

        swapCaller(users.owner);

        multistrategy.addStrategy(address(strategy), 10_000, 0, 100_000 ether);
    }

    function requestCredit(uint256 _amount) internal {
        dai.mint(users.bob, _amount);
        
        swapCaller(users.bob);
        dai.approve(address(multistrategy), _amount);
        IERC4626(address(multistrategy)).deposit(_amount, users.bob);

        // Switch back the caller to the owner, as stated in the setup funciton
        swapCaller(users.owner);

        strategy.requestCredit();
    }

    function transferStrategyAdapterOwnershipToOwner() internal {
        IOwnable(address(strategy)).transferOwnership(users.owner);
    }
}