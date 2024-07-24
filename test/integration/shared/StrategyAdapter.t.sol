// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.20 <0.9.0;

import { Base_Test } from "../../Base.t.sol";
import { IStrategyAdapter } from "interfaces/infra/multistrategy/IStrategyAdapter.sol";
import { IOwnable } from "../../shared/TestInterfaces.sol";

contract StrategyAdapter_Integration_Shared_Test is Base_Test {

    address strategy;

    function setUp() public virtual override {
        Base_Test.setUp();

        deployMultistrategy();
        transferMultistrategyOwnershipToOwner();
        strategy = deployMockStrategyAdapter(address(multistrategy), multistrategy.baseAsset());
        transferStrategyAdapterOwnershipToOwner();

        swapCaller(users.owner);

        multistrategy.addStrategy(strategy, 10_000, 0, 100_000 ether);
    }

    function requestCredit(uint256 _amount) internal {
        dai.mint(users.bob, _amount);
        
        swapCaller(users.bob);
        dai.approve(address(multistrategy), _amount);
        multistrategy.deposit(_amount, users.bob);

        // Switch back the caller to the owner, as stated in the setup funciton
        swapCaller(users.owner);

        IStrategyAdapter(strategy).requestCredit();
    }

    function transferStrategyAdapterOwnershipToOwner() internal {
        IOwnable(strategy).transferOwnership(users.owner);
    }
}