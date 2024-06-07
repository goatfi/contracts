// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { IMultistrategy } from "interfaces/infra/multistrategy/IMultistrategy.sol";
import { Multistrategy } from "src/infra/multistrategy/Multistrategy.sol";

import { ERC20Mock } from "./mocks/erc20/ERC20Mock.sol";
import { ERC20MissingReturn } from "./mocks/erc20/ERC20MissingReturn.sol";
import { StrategyAdapterMock } from "./mocks/StrategyAdapterMock.sol";
import { Test } from "forge-std/Test.sol";
import { Users } from "./utils/Types.sol";
import { Events } from "./utils/Events.sol";

abstract contract Base_Test is Test, Events {
    /*//////////////////////////////////////////////////////////////////////////
                                     VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    Users internal users;

    /*//////////////////////////////////////////////////////////////////////////
                                   TEST CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/

    IMultistrategy internal multistrategy;
    ERC20Mock internal dai;
    ERC20MissingReturn internal usdt;

    function setUp() public virtual {
        // Deploy the base test contracts.
        dai = new ERC20Mock("Dai Stablecoin", "DAI");
        usdt = new ERC20MissingReturn("Tether USD", "USDT", 6);

        // Label the base test contracts.
        vm.label({ account: address(dai), newLabel: "DAI" });
        vm.label({ account: address(usdt), newLabel: "USDT" });

        // Create users for testing.
        users = Users({
            owner: createUser("Owner"),
            keeper: createUser("Keeper"),
            guardian: createUser("Guardian"),
            feeRecipient: createUser("FeeRecipient"),
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

    function deployMultistrategy() internal {
        multistrategy = new Multistrategy({
            _depositToken: address(dai),
            _manager: users.keeper,
            _protocolFeeRecipient: users.feeRecipient,
            _name: "Goat DAI",
            _symbol: "GDAI"
        });

        // Enable Guardian
        multistrategy.enableGuardian(users.guardian);
        // Set deposit limit to 100K tokens
        multistrategy.setDepositLimit(100_000 ether);
        // Set performance fee to 5%
        multistrategy.setPerformanceFee(500);

        vm.label({ account: address(multistrategy), newLabel: "Multistrategy" });
    }

    function deployMockStrategyAdapter(address _multistrategy, address _depositToken) internal returns (address) {
        return address(new StrategyAdapterMock(_multistrategy, _depositToken));
    }

    function swapCaller(address newCaller) internal {
        vm.stopPrank();
        vm.startPrank(newCaller);
    } 
}
