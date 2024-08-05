// SPDX-License-Identifier: AGPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import "erc4626-tests/ERC4626.test.sol";
import { ERC20Mock } from "../../../mocks/erc20/ERC20Mock.sol";
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
        // setup initial shares and assets for individual users
        for (uint i = 0; i < N; i++) {
            address user = init.user[i];
            vm.assume(_isEOA(user));
            // shares
            uint shares = init.share[i];
            vm.assume(shares > 0 && shares <= depositLimit);
            try IMockERC20(_underlying_).mint(user, shares) {} catch { vm.assume(false); }
            _approve(_underlying_, user, _vault_, shares);
            vm.prank(user); try IERC4626(_vault_).deposit(shares, user) {} catch { vm.assume(false); }
            // assets
            uint assets = init.asset[i];
            try IMockERC20(_underlying_).mint(user, assets) {} catch { vm.assume(false); }
        }

        // setup initial yield for vault
        setUpYield(init);
    }

    function setUpYield(Init memory init) public override {
        if (init.yield >= 0) { // gain
            uint gain = uint(init.yield);
            try IMockERC20(_underlying_).mint(_vault_, gain) {} catch { vm.assume(false); }// this can be replaced by calling yield generating functions if provided by the vault
        } else { // loss
            vm.assume(init.yield > type(int).min); // avoid overflow in conversion
            uint loss = uint(-1 * init.yield);
            try IMockERC20(_underlying_).burn(_vault_, loss) {} catch { vm.assume(false); }// this can be replaced by calling yield generating functions if provided by the vault
        }
    }
}