// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import "forge-std/Test.sol";
import {GoatVault} from "src/infra/vault/GoatVault.sol";
import {IGoatVaultFactory} from "interfaces/infra/IGoatVaultFactory.sol";
import {IBalancerPool, IBalancerVault, IAsset} from "interfaces/aura/IBalancer.sol";
import {StratFeeManagerInitializable} from "src/infra/strategies/common/StratFeeManagerInitializable.sol";
import {IStrategy} from "interfaces/infra/IStrategy.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {ProtocolArbitrum} from "@addressbook/ProtocolArbitrum.sol";
import {AssetsArbitrum} from "@addressbook/AssetsArbitrum.sol";
import {IGoatSwapper} from "interfaces/infra/IGoatSwapper.sol";

// Strategy to deploy
import {StrategyAura} from "src/infra/strategies/aura/StrategyAura.sol";

contract GoatVaultDeploymentAuraTest is Test {
    /*//////////////////////////////////////////////////////////////////////////
                                   TEST CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/

    GoatVault vault;
    IGoatSwapper swapper;
    StrategyAura strategy;

    /*//////////////////////////////////////////////////////////////////////////
                                    VARIABLES
    //////////////////////////////////////////////////////////////////////////*/
    string name = "Goat Aura STAR-USDC";
    string symbol = "gASTAR-USDC";
    uint256 stratApprovalDelay = 21600;

    uint256 pid = 30;
    address want = 0xEAD7e0163e3b33bF0065C9325fC8fb9B18cc8213; // Balancer STAR/USDC stable pool
    address native = AssetsArbitrum.WETH;
    address depositToken = AssetsArbitrum.USDC;
    address starToken = 0xC19669A405067927865B40Ea045a2baabbbe57f5;

    address balancerVault = 0xBA12222222228d8Ba445958a75a0704d566BF2C8;
    bytes32 balethPoolId =
        0xb286b923a4ed32ef1eae425e2b2753f07a517708000200000000000000000000;
    bytes32 auraethPoolId =
        0x64abeae398961c10cbb50ef359f1db41fc3129ff000200000000000000000526;
    uint256 randomAmt = 4198024319081571;

    address[] rewards = [AssetsArbitrum.AURA, AssetsArbitrum.BAL];

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
        strategy = new StrategyAura();

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
            depositToken,
            rewards,
            commonAddresses
        );

        swapper = IGoatSwapper(ProtocolArbitrum.GOAT_SWAPPER);

        _addRewardToNativeSwapInfo(balethPoolId, AssetsArbitrum.BAL);
        _addRewardToNativeSwapInfo(auraethPoolId, AssetsArbitrum.AURA);
        _addDepositToWantSwapInfo();
    }

    function _addDepositToWantSwapInfo() internal {
        bytes32 poolId = IBalancerPool(want).getPoolId();

        IAsset[] memory tokens = new IAsset[](2);
        tokens[0] = IAsset(depositToken);
        tokens[1] = IAsset(starToken);

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = randomAmt; // random
        amounts[1] = 0;

        bytes memory userData = abi.encode(1, amounts);

        IBalancerVault.JoinPoolRequest memory request = IBalancerVault
            .JoinPoolRequest({
                assets: tokens,
                maxAmountsIn: amounts,
                userData: userData,
                fromInternalBalance: false
            });

        IGoatSwapper.SwapInfo memory swapInfo = IGoatSwapper.SwapInfo({
            router: balancerVault,
            data: abi.encodeWithSignature(
                "joinPool(bytes32,address,address,(address[],uint256[],bytes,bool))",
                poolId,
                ProtocolArbitrum.GOAT_SWAPPER,
                ProtocolArbitrum.GOAT_SWAPPER,
                request
            ),
            amountIndex: 388 // 32 * 12 + 4
        });
        vm.prank(0xbd297B4f9991FD23f54e14111EE6190C4Fb9F7e1);

        console.logBytes(
            abi.encodeWithSignature(
                "joinPool(bytes32,address,address,(address[],uint256[],bytes,bool))",
                poolId,
                ProtocolArbitrum.GOAT_SWAPPER,
                ProtocolArbitrum.GOAT_SWAPPER,
                request
            )
        );

        swapper.setSwapInfo(depositToken, want, swapInfo);
    }

    function _addRewardToNativeSwapInfo(
        bytes32 poolId,
        address token
    ) internal {
        IBalancerVault.SingleSwap memory singleSwap = IBalancerVault
            .SingleSwap({
                poolId: poolId,
                kind: IBalancerVault.SwapKind.GIVEN_IN,
                assetIn: IAsset(token),
                assetOut: IAsset(native),
                amount: randomAmt,
                userData: "0x"
            });

        IBalancerVault.FundManagement memory fundInfo = IBalancerVault
            .FundManagement({
                sender: address(swapper),
                fromInternalBalance: false,
                recipient: payable(address(swapper)),
                toInternalBalance: false
            });

        IGoatSwapper.SwapInfo memory swapInfo = IGoatSwapper.SwapInfo({
            router: balancerVault,
            data: abi.encodeWithSignature(
                "swap((bytes32,uint8,address,address,uint256,bytes),(address,bool,address,bool),uint256,uint256)",
                singleSwap,
                fundInfo,
                0,
                type(uint256).max
            ),
            amountIndex: 356 // 32 * 11 + 4
        });
        vm.prank(0xbd297B4f9991FD23f54e14111EE6190C4Fb9F7e1);

        swapper.setSwapInfo(token, native, swapInfo);
    }

    // function test_CanCompleteTestCycle() public {
    //     console.log("here");
    // }

    function test_CanCompleteTestCycle() public {
        // Get want
        uint256 amountToDeposit = 1000 * 10e6;
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

        vm.warp(block.timestamp + 1 days);

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