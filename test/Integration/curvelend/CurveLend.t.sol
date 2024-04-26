// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import "forge-std/Test.sol";
import {GoatVault} from "src/infra/vault/GoatVault.sol";
import {IGoatVaultFactory} from "interfaces/infra/IGoatVaultFactory.sol";
import {IBalancerPool, IBalancerVault} from "interfaces/aura/IBalancer.sol";
import {StratFeeManagerInitializable} from "src/infra/strategies/common/StratFeeManagerInitializable.sol";
import {IStrategy} from "interfaces/infra/IStrategy.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ProtocolArbitrum} from "@addressbook/ProtocolArbitrum.sol";
import {AssetsArbitrum} from "@addressbook/AssetsArbitrum.sol";
import {IGoatSwapper} from "interfaces/infra/IGoatSwapper.sol";

// Strategy to deploy
import {StrategyCurveLend} from "src/infra/strategies/curvelend/StrategyCurveLend.sol";

contract CurveLendTest is Test {
    /*//////////////////////////////////////////////////////////////////////////
                                   TEST CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/

    GoatVault vault;
    IGoatSwapper swapper;
    StrategyCurveLend strategy;

    /*//////////////////////////////////////////////////////////////////////////
                                    VARIABLES
    //////////////////////////////////////////////////////////////////////////*/
    string name = "Goat CurveLend WETH-Collateral";
    string symbol = "gCLWETH-Collateral";
    uint256 stratApprovalDelay = 21600;

    uint256 randomAmt = 4198024319081571;
    uint256 pid = 42069; // no_pid
    address want = 0x49014A8eB1585cBee6A7a9A50C3b81017BF6Cc4d;
    address gauge = 0xFD632Fa4fe5c2e2aeF32BD973CE1A68A517De461;
    address native = AssetsArbitrum.WETH;
    address depositToken = AssetsArbitrum.CRVUSD;

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

        IGoatVaultFactory vaultFactory = IGoatVaultFactory(
            ProtocolArbitrum.GOAT_VAULT_FACTORY
        );
        vault = vaultFactory.cloneVault();
        strategy = new StrategyCurveLend();

        commonAddresses = StratFeeManagerInitializable.CommonAddresses(
            address(vault),
            unirouter,
            keeper,
            strategist,
            protocolFeeRecipient,
            feeConfig
        );

        vault.initialize(
            IStrategy(address(strategy)),
            name,
            symbol,
            stratApprovalDelay
        );

        strategy.initialize(
            pid,
            native,
            gauge,
            depositToken,
            rewards,
            commonAddresses
        );

        swapper = IGoatSwapper(ProtocolArbitrum.GOAT_SWAPPER);

        _addDepositToWantSwapInfo();
    }

    function _addDepositToWantSwapInfo() internal {
        IGoatSwapper.SwapInfo memory swapInfo = IGoatSwapper.SwapInfo({
            router: address(want),
            data: abi.encodeWithSignature("deposit(uint256)", randomAmt),
            amountIndex: 4
        });
        vm.prank(0xbd297B4f9991FD23f54e14111EE6190C4Fb9F7e1);
        swapper.setSwapInfo(depositToken, want, swapInfo);
    }

    // function test_CanCompleteTestCycle() public {
    //     console.log("here");
    // }

    function test_CanCompleteTestCycle() public {
        // Get want
        uint256 amountToDeposit = 1000 * 10e18;
        deal(want, address(this), amountToDeposit);

        // Deposit
        IERC20(want).approve(address(vault), amountToDeposit);
        vault.deposit(amountToDeposit);

        vm.warp(block.timestamp + 1000);

        // Keeper panics the strategy
        vm.prank(keeper);
        strategy.panic();
        assertGe(IERC20(want).balanceOf(address(strategy)), amountToDeposit);

        // Keeper unpauses the strategy
        vm.prank(keeper);
        strategy.unpause();
        assertEq(IERC20(want).balanceOf(address(strategy)), 0);

        vm.warp(block.timestamp + 10 days);

        // Harvest and check that the fees go to the feeBatch and strategist
        uint256 feeBatchBalance = IERC20(native).balanceOf(
            protocolFeeRecipient
        );
        uint256 strategistBalance = IERC20(native).balanceOf(strategist);
        strategy.harvest();

        assertGt(
            IERC20(native).balanceOf(protocolFeeRecipient),
            feeBatchBalance
        );
        assertGt(IERC20(native).balanceOf(strategist), strategistBalance);

        // Check that after a harvest, the user got more of what he desposited
        vault.withdrawAll();
        assertGt(IERC20(want).balanceOf(address(this)), amountToDeposit);
        console.log(IERC20(want).balanceOf(address(this)));
    }
}
