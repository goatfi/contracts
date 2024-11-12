// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.20 <0.9.0;

import { IERC4626, Multistrategy_Integration_Shared_Test} from "../../../shared/Multistrategy.t.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import {IStrategyAdapter} from "interfaces/infra/multistrategy/IStrategyAdapter.sol";

contract MaxMint_Integration_Concrete_Test is Multistrategy_Integration_Shared_Test {
    uint8 decimals;
    function setUp() public virtual override {
        Multistrategy_Integration_Shared_Test.setUp();
        decimals = IERC20Metadata(IERC4626(address(multistrategy)).asset()).decimals();
    }
    function test_MaxMint_DepositLimitZero() external {
        triggerUserDeposit(users.bob, 1000 * 10 ** decimals);

        swapCaller(users.keeper); multistrategy.setDepositLimit(0);

        uint256 actualMaxMint = IERC4626(address(multistrategy)).maxMint(users.bob);
        uint256 expectedMaxMint = 0;
        assertEq(actualMaxMint, expectedMaxMint, "max mint");
    }

    modifier whenDepositLimitNotZero() {
        swapCaller(users.keeper); multistrategy.setDepositLimit(100_000 * 10 ** decimals);
        _;
    }

    function test_MaxMint_TotalAssetsZero()
        external
        whenDepositLimitNotZero
    {
        uint256 actualMaxMint = IERC4626(address(multistrategy)).maxMint(users.bob);
        uint256 expectedMaxMint = IERC4626(address(multistrategy)).convertToShares(multistrategy.depositLimit());
        assertEq(actualMaxMint, expectedMaxMint, "max mint");
    }

    modifier whenTotalAssetsNotZero() {
        triggerUserDeposit(users.bob, 1000 * 10 ** decimals);
        _;
    }

    function test_MaxMint()
        external
        whenDepositLimitNotZero
        whenTotalAssetsNotZero
    {
        uint256 depositLimit = multistrategy.depositLimit();
        uint256 totalAssets = IERC4626(address(multistrategy)).totalAssets();

        uint256 actualMaxMint = IERC4626(address(multistrategy)).maxMint(users.bob);
        uint256 expectedMaxMint = IERC4626(address(multistrategy)).convertToShares(depositLimit - totalAssets);
        assertEq(actualMaxMint, expectedMaxMint, "max mint");
    }
}