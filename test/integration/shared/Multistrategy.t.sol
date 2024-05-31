// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.20 <0.9.0;

import { Base_Test } from "../../Base.t.sol";

interface IOwnable {
    function transferOwnership(address newOwner) external;
}

contract Multistrategy_Integration_Shared_Test is Base_Test {
    function setUp() public virtual override {
        Base_Test.setUp();
        
        deployMultistrategy();
        transferMultistrategyOwnershipToOwner();

        vm.startPrank({ msgSender: users.owner });
    }

    function transferMultistrategyOwnershipToOwner() internal {
        IOwnable(address(multistrategy)).transferOwnership({ newOwner: users.owner });
    }
}