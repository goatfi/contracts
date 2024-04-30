// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { Test } from "forge-std/Test.sol";
import { Users } from "./Utils/Types.sol";

abstract contract Base_Test is Test {
    /*//////////////////////////////////////////////////////////////////////////
                                     VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    Users internal users;

    function setUp() public virtual {
        // Create users for testing.
        users = Users({
            owner: createUser("Owner"),
            keeper: createUser("Keeper"),
            alice: createUser("Alice"),
            bob: createUser("Bob")
        });
    }

    /// @dev Generates a user, labels its address, and funds it with test assets.
    function createUser(string memory name) internal returns (address payable) {
        address payable user = payable(makeAddr(name));
        vm.deal({account: user, newBalance: 100 ether});
        return user;
    }
}
