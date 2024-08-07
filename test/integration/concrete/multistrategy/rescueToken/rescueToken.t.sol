// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.20 <0.9.0;

import { IERC20Errors } from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import { IERC4626, Multistrategy_Integration_Shared_Test } from "../../../shared/Multistrategy.t.sol";
import { Errors } from "src/infra/libraries/Errors.sol";

contract RescueToken_Integration_Concrete_Test is Multistrategy_Integration_Shared_Test {
    function test_RevertWhen_CallerNotGuardian() external {
        swapCaller(users.bob);

        // Expect a revert
        vm.expectRevert(abi.encodeWithSelector(Errors.CallerNotGuardian.selector, users.bob));
        multistrategy.rescueToken(address(weth), users.bob);
    }

    modifier whenCallerIsGuardian() {
        swapCaller(users.guardian);
        _;
    }

    function test_RevertWhen_SameAddressAsset()
        external
        whenCallerIsGuardian
    {
        address baseAsset = IERC4626(address(multistrategy)).asset();
        // Expect a revert
        vm.expectRevert(abi.encodeWithSelector(Errors.InvalidAddress.selector, IERC4626(address(multistrategy)).asset()));
        multistrategy.rescueToken(baseAsset, users.bob);
    }

    modifier whenAddressNotAsset() {
        _;
    }

    function test_RevertWhen_ZeroAddress() 
        external
        whenCallerIsGuardian
        whenAddressNotAsset
    {
        // Expect a revert
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidReceiver.selector, address(0)));
        multistrategy.rescueToken(address(weth), address(0));
    }

    modifier whenNotZeroAddress() {
        _;
    }

    function test_RescueToken() 
        external
        whenCallerIsGuardian
        whenAddressNotAsset
        whenNotZeroAddress
    {   
        uint256 externalTokenBalance = 1000 ether;
        weth.mint(address(multistrategy), externalTokenBalance);

        // Assert the multistrategy has some external tokens to be rescued
        uint256 actualExternalTokenBalance = weth.balanceOf(address(multistrategy));
        uint256 expectedExternalTokenBalance = externalTokenBalance;
        assertEq(actualExternalTokenBalance, expectedExternalTokenBalance, "rescueToken");

        // Rescue tokens
        multistrategy.rescueToken(address(weth), users.guardian);

        // Assert the multistrategy does NOT have external tokens
        actualExternalTokenBalance = weth.balanceOf(address(multistrategy));
        expectedExternalTokenBalance = 0;
        assertEq(actualExternalTokenBalance, expectedExternalTokenBalance, "rescueToken");

        // Assert the recipient has received the tokens
        uint256 actualRecipientTokenBalance = weth.balanceOf(address(users.guardian));
        uint256 expectedRecipientTokenBalance = externalTokenBalance;
        assertEq(actualRecipientTokenBalance, expectedRecipientTokenBalance, "rescueToken");
    }
}