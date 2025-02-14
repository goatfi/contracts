// SPDX-License-Identifier: AGPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import "erc4626-tests/ERC4626.test.sol";
import { ERC20Mock } from "../../../mocks/erc20/ERC20Mock.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import { Multistrategy } from "src/infra/multistrategy/Multistrategy.sol";
import { IMultistrategyManageable } from "interfaces/infra/multistrategy/IMultistrategyManageable.sol";
import { StrategyAdapterMock } from "../../../mocks/StrategyAdapterMock.sol";

interface IOwnable {
  function owner() external view returns (address);
}

contract MultistrategyERC4626_Fuzz_Test is ERC4626Test {

    address manager = makeAddr("manager");
    address feeRecipient = makeAddr("fee");
    uint256 depositLimit = 100_000 ether;
    uint16 debtRatio = 2_000;
    uint16[] slippageLimit = [0, 10, 50, 100]; // 0, 0.1%, 0.5%, 1%
    uint16[] slippage = [0, 5, 20, 90]; // 0, 0.05%, 0.2%, 2%

    function setUp() public override {
        _underlying_ = address(new ERC20Mock("DAI Stablecoin", "DAI"));
        _vault_ = address(new Multistrategy(_underlying_, manager, feeRecipient, "DAI Multistrategy", "gDAI"));
        _delta_ = 0;
        _vaultMayBeEmpty = false;
        _unlimitedAmount = false;
    }

    function setUpVault(Init memory init) public override {
        IMultistrategyManageable(_vault_).setDepositLimit(depositLimit);
        secureDeposit();
        // setup initial shares and assets for individual users
        for (uint i = 0; i < N; i++) {
            address user = init.user[i];
            vm.assume(_isEOA(user));
            // shares
            uint shares = init.share[i];
            try IMockERC20(_underlying_).mint(user, shares) {} catch { vm.assume(false); }
            _approve(_underlying_, user, _vault_, shares);
            vm.prank(user); try IERC4626(_vault_).deposit(shares, user) {} catch { vm.assume(false); }
            // assets
            uint assets = init.asset[i];
            try IMockERC20(_underlying_).mint(user, assets) {} catch { vm.assume(false); }
            // strategies
            StrategyAdapterMock strategy = addStrategy();
            addMockSlippage(strategy, slippageLimit[i], slippage[i]);
            setUpYield(init, strategy);
        }
    }

    // setup initial yield
    function setUpYield(Init memory init, StrategyAdapterMock _strategy) public {
        vm.prank(manager); _strategy.requestCredit();
        if (init.yield >= 0) { // gain
            uint gain = uint(init.yield);
            vm.assume(gain <= type(uint).max / 1e10); // avoid overflow, as we perform this operation 4 times
            _strategy.earn(gain);
        } else { // loss
            vm.assume(init.yield > type(int).min); // avoid overflow in conversion
            uint loss = uint(-1 * init.yield);
            uint strategyAssets = _strategy.totalAssets();
            vm.assume(loss <= strategyAssets);
            _strategy.lose(loss);
        }
        vm.prank(manager); _strategy.sendReport(0);
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

    function addStrategy() public returns(StrategyAdapterMock) {
        vm.prank(manager); StrategyAdapterMock strategy = new StrategyAdapterMock(_vault_, _underlying_);
        vm.prank(IOwnable(_vault_).owner()); IMultistrategyManageable(_vault_).addStrategy(address(strategy), debtRatio, 0, type(uint256).max);
        return strategy;
    }

    function addMockSlippage(StrategyAdapterMock _strategy, uint16 _slippageLimit, uint16 _slippage) public {
        vm.prank(manager); _strategy.setSlippageLimit(uint(_slippageLimit));
        _strategy.setStakingSlippage(uint(_slippage));
    }
}