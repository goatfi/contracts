// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Test } from "forge-std/Test.sol";
import { Multistrategy } from "src/infra/multistrategy/Multistrategy.sol";
import { Users } from "../../utils/Types.sol";

abstract contract AdapterInvariantBase is Test {
    Users internal users;
    Multistrategy internal multistrategy;

    function createUsers() public {
        users = Users({
            owner: createUser("Owner"),
            keeper: createUser("Keeper"),
            guardian: createUser("Guardian"),
            feeRecipient: createUser("FeeRecipient"),
            alice: createUser("Alice"),
            bob: createUser("Bob")
        });
    }

    function createUser(string memory name) internal returns (address payable) {
        address payable user = payable(makeAddr(name));
        vm.deal({account: user, newBalance: 100 ether});
        vm.label({ account: address(user), newLabel: name });
        return user;
    }

    function createMultistrategy(address _asset, uint256 _depositLimit) public returns (Multistrategy) {
        vm.prank(users.owner); multistrategy = new Multistrategy({
            _asset: _asset,
            _manager: users.keeper,
            _protocolFeeRecipient: users.feeRecipient,
            _name: "",
            _symbol: ""
        });

        vm.prank(users.owner); multistrategy.enableGuardian(users.guardian);
        vm.prank(users.owner); multistrategy.setDepositLimit(_depositLimit);
        vm.prank(users.owner); multistrategy.setPerformanceFee(1000);

        vm.label({ account: address(multistrategy), newLabel: "Multistrategy" });
    }
}