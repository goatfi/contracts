// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.20 <0.9.0;

import { Base_Test } from "../../Base.t.sol";
import { IStrategyAdapter } from "interfaces/infra/multistrategy/IStrategyAdapter.sol";
import { IOwnable, IStrategyAdapterSlippage } from "../../shared/TestInterfaces.sol";

contract StrategyAdapter_Integration_Shared_Test is Base_Test {

    IStrategyAdapter strategy;
    IStrategyAdapterSlippage strategySlippage;

    function setUp() public virtual override {
        Base_Test.setUp();

        deployMultistrategy();
        transferMultistrategyOwnershipToOwner();
        strategy = IStrategyAdapter(deployMockStrategyAdapter(address(multistrategy), multistrategy.baseAsset()));
        strategySlippage = IStrategyAdapterSlippage(deployMockStrategyAdapterSlippage(address(multistrategy), multistrategy.baseAsset()));
        transferStrategyAdapterOwnershipToOwner();

        swapCaller(users.owner);
    }

    function requestCredit(address _strategy, uint256 _amount) internal {
        // Add the strategy to the multistrategy
        multistrategy.addStrategy(address(_strategy), 10_000, 0, 100_000 ether);
        dai.mint(users.bob, _amount);
        
        swapCaller(users.bob);
        dai.approve(address(multistrategy), _amount);
        multistrategy.deposit(_amount, users.bob);

        // Switch back the caller to the owner, as stated in the setup funciton
        swapCaller(users.owner);

        IStrategyAdapter(_strategy).requestCredit();
    }

    function transferStrategyAdapterOwnershipToOwner() internal {
        IOwnable(address(strategy)).transferOwnership(users.owner);
        IOwnable(address(strategySlippage)).transferOwnership(users.owner);
    }
}