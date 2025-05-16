// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Test } from "forge-std/Test.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import { Multistrategy } from "src/infra/multistrategy/Multistrategy.sol";
import { Users } from "../../utils/Types.sol";

abstract contract AdapterInvariantBase is Test {
    Users internal users;
    Multistrategy internal multistrategy;
    address asset;
    uint256 decimals;

    function setUp() public virtual {
        users = Users({
            owner: createUser("Owner"),
            keeper: createUser("Keeper"),
            guardian: createUser("Guardian"),
            feeRecipient: createUser("FeeRecipient"),
            alice: createUser("Alice"),
            bob: createUser("Bob")
        });

        decimals = IERC20Metadata(asset).decimals();
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

        return multistrategy;
    }

    function makeInitialDeposit(uint256 _amount) public {
        deal(asset, users.alice, _amount);
        vm.prank(users.alice); IERC20(asset).approve(address(multistrategy), _amount);
        vm.prank(users.alice); multistrategy.deposit(_amount, users.alice);
    }
}