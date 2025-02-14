// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.20 <0.9.0;

import { IERC4626, Multistrategy_Integration_Shared_Test} from "../../../shared/Multistrategy.t.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";

contract MaxDeposit_Integration_Concrete_Test is Multistrategy_Integration_Shared_Test {
    uint8 decimals;

    function setUp() public virtual override {
        Multistrategy_Integration_Shared_Test.setUp();
        decimals = IERC20Metadata(IERC4626(address(multistrategy)).asset()).decimals();
    }
    function test_MaxDeposit_DepositLimitZero() external {
        triggerUserDeposit(users.bob, 1000 * 10 ** decimals);

        swapCaller(users.keeper); multistrategy.setDepositLimit(0);

        uint256 actualMaxDeposit = IERC4626(address(multistrategy)).maxDeposit(users.bob);
        uint256 expectedMaxDeposit = 0;
        assertEq(actualMaxDeposit, expectedMaxDeposit, "max deposit");
    }

    modifier whenDepositLimitNotZero() {
        swapCaller(users.keeper); multistrategy.setDepositLimit(100_000 * 10 ** decimals);
        _;
    }

    function test_MaxDeposit_TotalAssetsZero()
        external
        whenDepositLimitNotZero
    {
        uint256 actualMaxDeposit = IERC4626(address(multistrategy)).maxDeposit(users.bob);
        uint256 expectedMaxDeposit = multistrategy.depositLimit();
        assertEq(actualMaxDeposit, expectedMaxDeposit, "max deposit");
    }

    modifier whenTotalAssetsNotZero() {
        triggerUserDeposit(users.bob, 1000 * 10 ** decimals);
        _;
    }

    function test_MaxDeposit()
        external
        whenDepositLimitNotZero
        whenTotalAssetsNotZero
    {
        uint256 actualMaxDeposit = IERC4626(address(multistrategy)).maxDeposit(users.bob);
        uint256 expectedMaxDeposit = multistrategy.depositLimit() - IERC4626(address(multistrategy)).totalAssets();
        assertEq(actualMaxDeposit, expectedMaxDeposit, "max deposit");
    }
}