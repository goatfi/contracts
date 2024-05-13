// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import "forge-std/Test.sol";
import { GoatVault } from "src/infra/vault/GoatVault.sol";
import { IGoatVaultFactory } from "interfaces/infra/IGoatVaultFactory.sol";
import { StratFeeManagerInitializable } from "src/infra/strategies/common/StratFeeManagerInitializable.sol";
import { IStrategy } from "interfaces/infra/IStrategy.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { ProtocolArbitrum } from "@addressbook/ProtocolArbitrum.sol";
import { AssetsArbitrum } from "@addressbook/AssetsArbitrum.sol";
import { IGoatSwapper } from "interfaces/infra/IGoatSwapper.sol";

// Strategy to deploy
import { StrategyCurveConvexL2 } from "src/infra/strategies/curve/StrategyCurveConvexL2.sol";

contract GoatVaultDeploymentCurveTest is Test {
    /*//////////////////////////////////////////////////////////////////////////
                                   TEST CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/

    GoatVault vault;
    StrategyCurveConvexL2 strategy;

    /*//////////////////////////////////////////////////////////////////////////
                                    VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    string name = "Goat CurveLend CRV-crvUSD";
    string symbol = "gCurveLendCRV-crvUSD";
    uint256 stratApprovalDelay = 21_600;

    uint256 pid = 42069;
    address native = AssetsArbitrum.WETH;
    address want = 0xeEaF2ccB73A01deb38Eca2947d963D64CfDe6A32;
    address depositToken = AssetsArbitrum.CRVUSD;
    address gauge = 0xb999E6177CAc62d40f2FDD1fE396DaD411F40499;

    address[] rewards = [AssetsArbitrum.CRV, AssetsArbitrum.ARB];

    StratFeeManagerInitializable.CommonAddresses commonAddresses;

    address unirouter = ProtocolArbitrum.GOAT_SWAPPER;
    address keeper = ProtocolArbitrum.TREASURY;
    address strategist = 0xbd297B4f9991FD23f54e14111EE6190C4Fb9F7e1;
    address protocolFeeRecipient = ProtocolArbitrum.GOAT_FEE_BATCH;
    address feeConfig = ProtocolArbitrum.FEE_CONFIG;

    /*//////////////////////////////////////////////////////////////////////////
                                  SET-UP FUNCTION
    //////////////////////////////////////////////////////////////////////////*/

    function setUp() public virtual {
        vm.createSelectFork(vm.envString("ARBITRUM_RPC_URL"));

        IGoatVaultFactory vaultFactory = IGoatVaultFactory(ProtocolArbitrum.GOAT_VAULT_FACTORY);
        vault = vaultFactory.cloneVault();
        strategy = new StrategyCurveConvexL2();

        commonAddresses = StratFeeManagerInitializable.CommonAddresses(address(vault), unirouter, keeper, strategist, protocolFeeRecipient, feeConfig);

        vault.initialize(IStrategy(address(strategy)), name, symbol, stratApprovalDelay);
        strategy.initialize(native, want, gauge, pid, depositToken, rewards, commonAddresses);
    }

    function test_CanCompleteTestCycle() public {
        // Get want
        uint256 amountToDeposit = 100 ether;
        deal(want, address(this), amountToDeposit);

        // Deposit
        IERC20(want).approve(address(vault), amountToDeposit);
        vault.deposit(amountToDeposit);

        vm.warp(block.timestamp + 1000);

        // Keeper panics the strategy
        vm.prank(keeper);
        strategy.panic();
        assertEq(IERC20(want).balanceOf(address(strategy)), amountToDeposit);

        // Keeper unpauses the strategy
        vm.prank(keeper);
        strategy.unpause();
        assertEq(IERC20(want).balanceOf(address(strategy)), 0);

        vm.warp(block.timestamp + 10_000);

        // Harvest and check that the fees go to the feeBatch and strategist
        uint256 feeBatchBalance = IERC20(native).balanceOf(protocolFeeRecipient);
        uint256 strategistBalance = IERC20(native).balanceOf(strategist);
        strategy.harvest();
        assertGt(IERC20(native).balanceOf(protocolFeeRecipient), feeBatchBalance);
        assertGt(IERC20(native).balanceOf(strategist), strategistBalance);

        // Check that after a harvest, the user got more of what he desposited
        vault.withdrawAll();
        assertGt(IERC20(want).balanceOf(address(this)), amountToDeposit);
        console.log(IERC20(want).balanceOf(address(this)));
    }
}
