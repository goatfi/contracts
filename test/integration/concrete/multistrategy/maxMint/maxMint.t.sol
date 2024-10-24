// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.20 <0.9.0;

import { IERC4626, Multistrategy_Integration_Shared_Test} from "../../../shared/Multistrategy.t.sol";
import {IStrategyAdapter} from "interfaces/infra/multistrategy/IStrategyAdapter.sol";

contract MaxMint_Integration_Concrete_Test is Multistrategy_Integration_Shared_Test {
    function test_MaxMint_DepositLimitZero() external {
        triggerUserDeposit(users.bob, 1000 ether);

        swapCaller(users.keeper); multistrategy.setDepositLimit(0);

        uint256 actualMaxMint = IERC4626(address(multistrategy)).maxMint(users.bob);
        uint256 expectedMaxMint = 0;
        assertEq(actualMaxMint, expectedMaxMint, "max mint");
    }

    modifier whenDepositLimitNotZero() {
        swapCaller(users.keeper); multistrategy.setDepositLimit(100_000 ether);
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
        triggerUserDeposit(users.bob, 1000 ether);
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