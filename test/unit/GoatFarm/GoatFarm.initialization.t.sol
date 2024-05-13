// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import { GoatFarmTestBase } from "./GoatFarmBase.t.sol";

contract GoatFarmInitializationTest is GoatFarmTestBase {

    address private owner;

    function setUp() public override {
        GoatFarmTestBase.setUp();
        owner = address(this);
    }

    /// @dev Contract is initialized when creating a farm via the factory on GoatFarmTestBase
    function test_InitializedParameters() public {
        assertEq(address(farm.stakedToken()), address(stakedToken));
        assertEq(address(farm.rewardToken()), address(rewardToken));
        assertEq(farm.owner(), owner);
        assertEq(farm.manager(), owner);
        assertEq(farm.duration(), DURATION);
    }
}
