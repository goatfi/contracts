// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import { Test } from "forge-std/Test.sol";
import { Multistrategy } from "src/infra/multistrategy/Multistrategy.sol";
import { ERC4626Adapter } from "src/infra/multistrategy/adapters/ERC4626Adapter.sol";
import { AdapterIntegration } from "./shared/AdapterIntegration.t.sol";
import { AssetsArbitrum } from "@addressbook/AssetsArbitrum.sol";
import { ProtocolArbitrum } from "@addressbook/ProtocolArbitrum.sol";

contract ERC4626AdapterIntegration is AdapterIntegration {
    function setUp() public override {
        vm.createSelectFork(vm.envString("ARBITRUM_RPC_URL"));
        super.setUp();

        asset = AssetsArbitrum.USDT;
        depositLimit = 10_000 * (10 ** IERC20Metadata(asset).decimals());
        minDeposit = (10 ** IERC20Metadata(asset).decimals() - 2);
        harvest = false;

        createMultistrategy(asset, depositLimit);
        createStargateAdapterNative();
    }

    function createStargateAdapterNative() public {
        address vault = 0x4A03F37e7d3fC243e3f99341d36f4b829BEe5E03;

        vm.prank(users.keeper); adapter = new ERC4626Adapter(address(multistrategy), asset, vault, "", "");
        vm.prank(users.keeper); adapter.enableGuardian(users.guardian);
    }

    function testFuzz_AdapterLifeCycle(uint256 _depositAmount, uint256 _withdrawAmount, uint256 _yieldTime, uint256 _debtRatio) public {
        _depositAmount = bound(_depositAmount, minDeposit, multistrategy.depositLimit());
        _withdrawAmount = bound(_withdrawAmount, 1, _depositAmount);
        _yieldTime = bound(_yieldTime, 1 hours, 10 * 365 days);
        _debtRatio = bound(_debtRatio, 0, 10_000);

        super.adapterLifeCycle(_depositAmount, _withdrawAmount, _yieldTime, _debtRatio);

        uint256 currentBalance = IERC20(asset).balanceOf(users.bob);
        assertGt(currentBalance, _depositAmount);
    }

    function testFuzz_AdapterPanicProcedure(uint256 _depositAmount, uint256 _withdrawAmount, uint256 _yieldTime, uint256 _debtRatio) public {
        _depositAmount = bound(_depositAmount, minDeposit, multistrategy.depositLimit());
        _withdrawAmount = bound(_withdrawAmount, 1, _depositAmount);
        _yieldTime = bound(_yieldTime, 1 hours, 10 * 365 days);
        _debtRatio = bound(_debtRatio, 0, 10_000);

        super.adapterPanicProcedure(_depositAmount, _withdrawAmount, _yieldTime, _debtRatio);

        assertApproxEqAbs(adapter.totalAssets(), 0, 1);
        assertApproxEqAbs(multistrategy.totalAssets(), IERC20(asset).balanceOf(address(multistrategy)), 1);
    }

    function test_AdapterMixer() public {
        super.adapterMixer();

        uint256 pps = multistrategy.pricePerShare();
        assertGt(pps, 10 ** IERC20Metadata(asset).decimals());
    }
}