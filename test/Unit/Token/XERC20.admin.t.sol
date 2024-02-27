// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import { XERC20TestBase } from "./XERC20Base.t.sol";

contract XERC20AdminTest is XERC20TestBase {

    /*//////////////////////////////////////////////////////////////////////////
                                   CONSTANTS
    //////////////////////////////////////////////////////////////////////////*/

    address private constant BRIDGE = 0xC1893fD65B9b7347DDc2E1e29bab168E6c6df69E;

    function setUp() public override {
        XERC20TestBase.setUp();

        minterLimits[0] = 100_000 ether;
        burnerLimits[0] = 100_000 ether;
        bridgeAdapters[0] = BRIDGE;

        xGoa.setLimits(bridgeAdapters[0], minterLimits[0], burnerLimits[0]);

        vm.startPrank(BRIDGE);
    }

    function test_BridgeCanMintXERC20() public {
        _mintToUser(1000 ether);

        assertEq(erc20xGoa.balanceOf(USER), 1000 ether);
        assertEq(xGoa.mintingCurrentLimitOf(BRIDGE), 99_000 ether);
    }

    function test_BridgeCanBurnXERC20() public {
        _mintAndApprove(1000 ether);

        xGoa.burn(USER, 1000 ether);

        assertEq(erc20xGoa.balanceOf(USER), 0 ether);
        assertEq(xGoa.burningCurrentLimitOf(BRIDGE), 99_000 ether);
    }

    function test_RevertWhen_MinitngOverLimit() public {
        vm.expectRevert(bytes4(keccak256("IXERC20_NotHighEnoughLimits()")));
        _mintToUser(101_000 ether);
    }

    /**
     * @dev Waits 1 day between mints. Current minting limit is 100K and need to mint 101K.
     */
    function test_RevertWhen_BurningOverLimit() public {
        _mintToUser(100_000 ether);
        vm.warp(block.timestamp + 1 days);
        _mintToUser(1_000 ether);
        _increaseUserApproval(101_000 ether);

        vm.expectRevert(bytes4(keccak256("IXERC20_NotHighEnoughLimits()")));
        xGoa.burn(USER, 101_000 ether);
    }

    function test_GetMintingMaxLimit() public {
        assertEq(xGoa.mintingMaxLimitOf(BRIDGE), 100_000 ether);
    }

    function test_GetBurningMaxLimit() public {
        assertEq(xGoa.burningMaxLimitOf(BRIDGE), 100_000 ether);
    }

    function test_MintingCurrentLimitReset() public {
        _mintToUser(100_000 ether);

        assertEq(xGoa.mintingCurrentLimitOf(BRIDGE), 0);
        vm.warp(block.timestamp + 1 days);
        assertEq(xGoa.mintingCurrentLimitOf(BRIDGE), 100_000 ether);
    }

    function test_BurningCurrentLimitReset() public {
        _mintAndApprove(100_000 ether);
        xGoa.burn(USER, 100_000 ether);

        assertEq(xGoa.burningCurrentLimitOf(BRIDGE), 0);
        vm.warp(block.timestamp + 1 days);
        assertEq(xGoa.burningCurrentLimitOf(BRIDGE), 100_000 ether);
    }

    function test_ChangeLimits() public {
        vm.stopPrank();
        xGoa.setLimits(BRIDGE, 50_000 ether, 50_000 ether);

        assertEq(xGoa.mintingCurrentLimitOf(BRIDGE), 50_000 ether);
        assertEq(xGoa.burningCurrentLimitOf(BRIDGE), 50_000 ether);
        assertEq(xGoa.mintingMaxLimitOf(BRIDGE), 50_000 ether);
        assertEq(xGoa.burningMaxLimitOf(BRIDGE), 50_000 ether);
    }

    /**
     * @dev Even the deployer shouldn't be allowed to change the Lockbox
     */
    function test_RevertWhen_ChangeLockbox() public {
        vm.stopPrank();

        vm.expectRevert(bytes4(keccak256("IXERC20_NotFactory()")));
        xGoa.setLockbox(address(0xdead));
    }

    /**
     * @dev Utils function for burn test where the user must have xGOA.
     * @param _amount xGoa to be minted and approved for burn.
     */
    function _mintAndApprove(uint256 _amount) private {
        _mintToUser(_amount);
        _increaseUserApproval(_amount);
    }

    function _mintToUser(uint256 _amount) private {
         xGoa.mint(USER, _amount);
    }

    function _increaseUserApproval(uint256 _amount) private {
        uint256 approveAmount = erc20xGoa.allowance(USER, BRIDGE) + _amount;

        vm.stopPrank();
        vm.prank(USER);
        erc20xGoa.approve(BRIDGE, approveAmount);
        vm.startPrank(BRIDGE);
    }
}