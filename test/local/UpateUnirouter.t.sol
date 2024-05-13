// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../../src/infra/strategies/equilibria/StrategyEquilibria.sol";
import { ProtocolArbitrum } from "@addressbook/ProtocolArbitrum.sol";
import { AssetsArbitrum } from "@addressbook/AssetsArbitrum.sol";

interface IStrategy {
    function owner() external view returns (address);
    function updateUnirouter(address unirouter) external;
    function unirouter() external view returns (address);
    function balanceOf() external view returns (uint256);
    function harvest() external;
    function setDepositToken(address token) external;
}

contract UpgradeUnirouterTest is Test {
    IStrategy strategy = IStrategy(0xA79b2b1CC042CD21f317d11A2Eb7cb051599587e);
    address unirouter = ProtocolArbitrum.GOAT_SWAPPER;

    function setUp() public {
        vm.createSelectFork(vm.envString("ARBITRUM_RPC_URL"));
    }

    function test_UpdateUnirouter() public {
        vm.startPrank(strategy.owner());
        strategy.updateUnirouter(unirouter);
        strategy.setDepositToken(AssetsArbitrum.WETH);
        vm.stopPrank();

        // Assert the unirouter was updated correctly
        assertEq(strategy.unirouter(), unirouter);

        uint256 balance = strategy.balanceOf();
        strategy.harvest();

        assertGt(strategy.balanceOf(), balance);
    }
}
