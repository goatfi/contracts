// SPDX-License-Identifier: AGPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import "erc4626-tests/ERC4626.test.sol";
import { ERC20Mock } from "../../../mocks/erc20/ERC20Mock.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import { Multistrategy } from "src/infra/multistrategy/Multistrategy.sol";
import { IMultistrategyManageable } from "interfaces/infra/multistrategy/IMultistrategyManageable.sol";

contract ERC4626StdTest is ERC4626Test {

    address owner = makeAddr("owner");
    uint256 depositLimit = 100_000 ether;

    function setUp() public override {
        _underlying_ = address(new ERC20Mock("DAI Stablecoin", "DAI"));
        _vault_ = address(new Multistrategy(_underlying_, owner, makeAddr("fee"), "DAI Multistrategy", "gDAI"));
        _delta_ = 0;
        _vaultMayBeEmpty = false;
        _unlimitedAmount = false;
    }

    function setUpVault(Init memory init) public override {
        IMultistrategyManageable(_vault_).setDepositLimit(depositLimit);
        secureDeposit();
        super.setUpVault(init);
    }

    // Each multistrategy will have security deposit that will be "burned"
    // SecureDeposit will be of 1 underlying token
    // This is made to prevent inflation attacks
    function secureDeposit() public {
        address secureDepositor = makeAddr("secureDepositor");
        uint256 shares = 10 ** IERC20Metadata(_underlying_).decimals();
        try IMockERC20(_underlying_).mint(secureDepositor, shares) {} catch { vm.assume(false); }
        _approve(_underlying_, secureDepositor, _vault_, shares);
        vm.prank(secureDepositor); try IERC4626(_vault_).deposit(shares, secureDepositor) {} catch { vm.assume(false); }
        vm.prank(secureDepositor); try IERC20(_vault_).transfer(address(42069), shares) {} catch { vm.assume(false); }
    }
}