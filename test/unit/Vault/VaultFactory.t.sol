// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import { GoatVault } from "src/infra/vault/GoatVault.sol";
import { GoatVaultFactory } from "src/infra/vault/GoatVaultFactory.sol";
import { IStrategy } from "interfaces/infra/IStrategy.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

contract GoatVaultFactoryTest is Test {

    error InvalidInitialization();

    /*//////////////////////////////////////////////////////////////////////////
                                   TEST CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/

    GoatVaultFactory vaultFactory;
    GoatVault vault;

    /*//////////////////////////////////////////////////////////////////////////
                                  SET-UP FUNCTION
    //////////////////////////////////////////////////////////////////////////*/

    function setUp() public virtual {
        vaultFactory = new GoatVaultFactory(address(0));
        vault = vaultFactory.instance();
    }

    function test_RevertWhen_InitializeImplementation() public {
        vm.expectRevert(InvalidInitialization.selector);
        vault.initialize(IStrategy(address(0)), "", "", 0);

        assertEq(vaultFactory.instance().owner(), address(0));
        assertEq(IERC20Metadata(address(vaultFactory.instance())).name(), "Goat Vault Implementation");
    }
}
