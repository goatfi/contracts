// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Multistrategy } from "src/infra/multistrategy/Multistrategy.sol";
import { MultistrategyHarness } from "./shared/MultistrategyHarness.sol";
import { ERC20Mock } from "./mocks/erc20/ERC20Mock.sol";
import { ERC20MissingReturn } from "./mocks/erc20/ERC20MissingReturn.sol";
import { StrategyAdapterMock } from "./mocks/StrategyAdapterMock.sol";
import { IOwnable } from "./shared/TestInterfaces.sol";
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

    Multistrategy internal multistrategy;
    MultistrategyHarness internal multistrategyHarness;
    ERC20Mock internal dai;
    ERC20Mock internal weth;
    ERC20MissingReturn internal usdt;

    function setUp() public virtual {
        dai = new ERC20Mock("Dai Stablecoin", "DAI");
        weth = new ERC20Mock("Wrapped Ether", "WETH");
        usdt = new ERC20MissingReturn("Tether USD", "USDT", 6);

        vm.label({ account: address(dai), newLabel: "DAI" });
        vm.label({ account: address(usdt), newLabel: "USDT" });

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
        vm.label({ account: address(user), newLabel: name });
        return user;
    }

    function deployMultistrategy() internal {
        multistrategy = new Multistrategy({
            _asset: address(usdt),
            _manager: users.keeper,
            _protocolFeeRecipient: users.feeRecipient,
            _name: "Goat DAI",
            _symbol: "GDAI"
        });

        multistrategy.enableGuardian(users.guardian);
        multistrategy.setDepositLimit(100_000 * 10 ** usdt.decimals());
        multistrategy.setPerformanceFee(500);

        vm.label({ account: address(multistrategy), newLabel: "Multistrategy" });
    }

    function deployMultistrategyHarness() internal {
        multistrategyHarness = new MultistrategyHarness({
            _asset: address(dai),
            _manager: users.keeper,
            _protocolFeeRecipient: users.feeRecipient,
            _name: "Goat DAI",
            _symbol: "GDAI"
        });

        multistrategyHarness.enableGuardian(users.guardian);
        multistrategyHarness.setDepositLimit(100_000 ether);
        multistrategyHarness.setPerformanceFee(500);

        vm.label({ account: address(multistrategyHarness), newLabel: "Multistrategy Harness" });
    }

    function deployMockStrategyAdapter(address _multistrategy, address _asset) internal returns (StrategyAdapterMock) {
        return new StrategyAdapterMock(_multistrategy, _asset);
    }

    function transferMultistrategyOwnershipToOwner() internal {
        if(address(multistrategyHarness) == address(0)){
            IOwnable(address(multistrategy)).transferOwnership({ newOwner: users.owner });
        } else {
            IOwnable(address(multistrategyHarness)).transferOwnership({ newOwner: users.owner });
        }
    }

    function swapCaller(address newCaller) internal {
        vm.stopPrank();
        vm.startPrank(newCaller);
    } 
}
