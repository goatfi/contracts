// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import { MockERC20 } from "lib/solmate/src/test/utils/mocks/MockERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { TokenManager } from "src/infra/instantDeposit/TokenManager.sol";
import { InstantDepositErrors } from "src/infra/instantDeposit/InstantDepositErrors.sol";
import { IInstantDepositRouter } from "interfaces/infra/instantDeposit/IInstantDepositRouter.sol";
import { ITokenManager } from "interfaces/infra/instantDeposit/ITokenManager.sol";

contract MockInstantDepositRouter {

    address public immutable tokenManager;

    constructor() {
        tokenManager = address(new TokenManager());
    }

    function executeOrder(IInstantDepositRouter.Order calldata _order) external {
        ITokenManager(tokenManager).pullTokens(_order.user, _order.inputs);
    }
}
 
contract TokenManagerTest is Test {
    /*//////////////////////////////////////////////////////////////////////////
                                   CONSTANTS
    //////////////////////////////////////////////////////////////////////////*/

    address internal immutable BOB = makeAddr("bob");

    /*//////////////////////////////////////////////////////////////////////////
                                   TEST CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/

    MockInstantDepositRouter internal idRouter;
    MockERC20 internal token;
    ITokenManager internal tokenManager;

    /*//////////////////////////////////////////////////////////////////////////
                                  SET-UP FUNCTION
    //////////////////////////////////////////////////////////////////////////*/

    function setUp() public {
        token = new MockERC20("Token", "TKN", 18);
        idRouter = new MockInstantDepositRouter();
        tokenManager = ITokenManager(idRouter.tokenManager());
        token.mint(BOB, 100 ether);
        vm.startPrank(BOB);
        IERC20(address(token)).approve(address(tokenManager), IERC20(address(token)).balanceOf(BOB));
        vm.stopPrank();
    }

    function test_PullTokens() public {
        uint256 initialBalance = IERC20(address(token)).balanceOf(BOB);
        IInstantDepositRouter.Order memory order = _generateOrder();

        idRouter.executeOrder(order);

        assertEq(IERC20(address(token)).balanceOf(BOB), 0);
        assertEq(IERC20(address(token)).balanceOf(address(idRouter)), initialBalance);
    }

    function test_RevertWhen_NotPullingFromInstantDeposit() public {
        IInstantDepositRouter.Order memory order = _generateOrder();
        
        vm.startPrank(BOB);
        vm.expectRevert(abi.encodeWithSelector(InstantDepositErrors.CallerNotInstantDeposit.selector, BOB));
        tokenManager.pullTokens(order.user, order.inputs);
        vm.stopPrank();
    }

    function _generateOrder() internal view returns (IInstantDepositRouter.Order memory order) {
        IInstantDepositRouter.Input[] memory inputs = new IInstantDepositRouter.Input[](1);
        IInstantDepositRouter.Output[] memory outputs = new IInstantDepositRouter.Output[](1);
        IInstantDepositRouter.Relay memory relay;

        uint256 initialBalance = IERC20(address(token)).balanceOf(BOB);

        inputs[0] = IInstantDepositRouter.Input({token: address(token), amount: initialBalance});
        outputs[0] = IInstantDepositRouter.Output({token: address(0), minOutputAmount: 0});
        relay = IInstantDepositRouter.Relay({target: address(0), value: 0, data: "0x00"});

        order = IInstantDepositRouter.Order({
            inputs: inputs,
            outputs: outputs,
            relay: relay,
            user: BOB,
            recipient: address(idRouter)
        });
    }
}