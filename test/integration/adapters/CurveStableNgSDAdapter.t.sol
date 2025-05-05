// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { AdapterIntegration } from "./shared/AdapterIntegration.t.sol";
import { AssetsArbitrum, ProtocolArbitrum } from "@addressbook/AddressBook.sol";
import { StrategyAdapterHarvestable } from "src/abstracts/StrategyAdapterHarvestable.sol";
import { IStrategyAdapterHarvestable } from "interfaces/infra/multistrategy/IStrategyAdapterHarvestable.sol";
import { CurveStableNgSDAdapter } from "src/infra/multistrategy/adapters/CurveStableNgSDAdapter.sol";
import { CurveStableNgSlippageUtility } from "src/infra/utilities/curve/CurveStableNgSlippageUtility.sol";
import { Errors } from "src/infra/libraries/Errors.sol";

interface ICurveStableNgSDAdapter {
    function getDepositSlippage(uint256 _amount) external view returns (uint256 slippage, bool positive);
    function getWithdrawSlippage(uint256 _amount) external view returns (uint256 slippage, bool positive);
    function curveSlippageLimit() external view returns (uint256 slippageLimit);
    function setCurveSlippageLimit(uint256 _slippageLimit) external;
    function setBufferPPM(uint256 _ppm) external;
}

interface ICurveLP {
    function calc_token_amount(uint256[] memory amounts, bool isDeposit) external view returns (uint256);
    function calc_withdraw_one_coin(uint256 vaultShares, int128 index) external view returns (uint256);
}

contract CurveStableNgSDAdapterIntegration is AdapterIntegration {
    using Math for uint256;

    CurveStableNgSlippageUtility curveUtility;

    function setUp() public override {
        vm.createSelectFork(vm.envString("ARBITRUM_RPC_URL"));
        asset = AssetsArbitrum.USDT;
        super.setUp();

        depositLimit = 100_000 * (10 ** decimals);
        minDeposit = 10 * (10 ** decimals);
        minDebtDelta = 1 * (10 ** decimals);
        harvest = true;
        curveUtility = new CurveStableNgSlippageUtility();

        createMultistrategy();
        createCurveAdapter();

        vm.prank(users.owner); multistrategy.setSlippageLimit(1);
    }

    function createCurveAdapter() public {
        uint256 slippageLimit = 0.1 ether;
        CurveStableNgSDAdapter.CurveSNGSDData memory curveData = CurveStableNgSDAdapter.CurveSNGSDData({
            curveLiquidityPool: 0x49b720F1Aab26260BEAec93A7BeB5BF2925b2A8F,
            sdVault: 0xa8D278db4ca48e7333901b24A83505BB078ecF86,
            sdRewards: 0xAbf4368d120190B4F111C30C92cc9f8f6a6BE233,
            curveSlippageUtility: address(curveUtility),
            assetIndex: 1
        });
        StrategyAdapterHarvestable.HarvestAddresses memory harvestAddresses = StrategyAdapterHarvestable.HarvestAddresses({
            swapper: ProtocolArbitrum.GOAT_SWAPPER,
            wrappedGas: AssetsArbitrum.WETH
        });

        adapter = new CurveStableNgSDAdapter(address(multistrategy), multistrategy.asset(), harvestAddresses, curveData, "", "");
        adapter.transferOwnership(users.keeper);

        vm.startPrank(users.keeper);
        adapter.enableGuardian(users.guardian);
        adapter.setSlippageLimit(1);
        IStrategyAdapterHarvestable(address(adapter)).addReward(AssetsArbitrum.CRV);
        ICurveStableNgSDAdapter(address(adapter)).setCurveSlippageLimit(slippageLimit);
        ICurveStableNgSDAdapter(address(adapter)).setBufferPPM(2);
        vm.stopPrank();
    }

    function test_RevertWhen_callerNotOwner() public {
        uint256 newLimit = 50 ether;
        vm.startPrank(users.alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector, 
                users.alice
            )
        );
        ICurveStableNgSDAdapter(address(adapter)).setCurveSlippageLimit(newLimit);
        vm.stopPrank();
    }

    function test_RevertWhen_SlippageAboveLimit() public {
        uint256 excessiveLimit = 101 ether;

        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.SlippageLimitExceeded.selector, 
                excessiveLimit
            )
        );
        vm.prank(users.keeper); ICurveStableNgSDAdapter(address(adapter)).setCurveSlippageLimit(excessiveLimit);
    }

    function test_SetCurveSlippageLimit() public {
        uint256 newLimit = 50 ether;

        vm.prank(users.keeper); ICurveStableNgSDAdapter(address(adapter)).setCurveSlippageLimit(newLimit);

        assertEq(ICurveStableNgSDAdapter(address(adapter)).curveSlippageLimit(), newLimit);
    }

    function testFuzz_AdapterPanicProcedure(uint256 _depositAmount, uint256 _withdrawAmount, uint256 _yieldTime, uint256 _debtRatio) public {
        super.adapterPanicProcedure(_depositAmount, _withdrawAmount, _yieldTime, _debtRatio);

        assertEq(adapter.totalAssets(), 0);
        //assertEq(multistrategy.totalAssets(), IERC20(asset).balanceOf(address(multistrategy)));
    }

    // Observations:
    // The smaller the buffer, the higher minDebtDelta has to be.
    // A buffer of 2 PPM can handle 1 token minDebtDelta
    function testFuzz_sharesMatch(uint256 _amount) public view {
        ICurveLP curveLiquidityPool = ICurveLP(0x49b720F1Aab26260BEAec93A7BeB5BF2925b2A8F);
        uint256 lpTokenBalance = IERC20(asset).balanceOf(address(curveLiquidityPool));

        uint256 ONE_PPM      = 1_000_000;   // 1 part-per-million = 0.0001 %
        uint256 PPM_BUFFER   = ONE_PPM + 2; // 1 000 002  (adds 2 ppm)
        uint256 amount = bound(_amount, 1 * (10 ** decimals), lpTokenBalance.mulDiv(0.99 ether, 1 ether));
        uint256[] memory amounts = new uint256[](2);
        amounts[1] = amount;

        uint256 lpSharesNeeded = curveLiquidityPool.calc_token_amount(amounts, false);

        lpSharesNeeded = lpSharesNeeded.mulDiv(PPM_BUFFER, ONE_PPM);
        uint256 receivedAmount = curveLiquidityPool.calc_withdraw_one_coin(lpSharesNeeded, 1);

        assertGe(receivedAmount, amount);
    }
}
