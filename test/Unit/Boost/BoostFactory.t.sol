// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import { BoostFactory } from "src/infra/boost/BoostFactory.sol";
import { GoatVaultFactory } from "src/infra/vault/GoatVaultFactory.sol";
import { GoatBoost } from "src/infra/boost/GoatBoost.sol";
import { IGoatBoost } from "interfaces/infra/IGoatBoost.sol";

contract BoostFactoryTest is Test {
    BoostFactory public boostFactory;
    IGoatBoost public goatBoost;
    address public vaultFactory;
    address public boostImpl;

    address vault = address(0x01);
    address rewardToken = address(0x02);
    address manager = address(0x03);
    address treasury = address(0x04);
    uint256 boostLength = 7 * 24 * 60 * 60; //In Seconds

    function setUp() public {
        vaultFactory = address(new GoatVaultFactory(address(0)));
        boostImpl = address(new GoatBoost());
        boostFactory = new BoostFactory(vaultFactory, boostImpl);
    }

    function test_DeployBoostViaFactory() public {
        goatBoost = IGoatBoost(boostFactory.deployBoost(vault, rewardToken, boostLength, manager, treasury));

        assertEq(address(goatBoost.stakedToken()), vault, "Staked token should match");
        assertEq(address(goatBoost.rewardToken()), rewardToken, "Reward token should match");
        assertEq(goatBoost.duration(), boostLength, "Duration should match");
        assertEq(goatBoost.manager(), manager, "Manager should match");
        assertEq(goatBoost.treasury(), treasury, "Treasury should match");
        assertEq(goatBoost.treasuryFee(), 0, "Treasury fee should be zero");
        assertEq(goatBoost.owner(), address(boostFactory.deployer()), "Ownership should be transferred to the deployer");
    }
}