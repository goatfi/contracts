// SPDX-License-Identifier: GNU AGPLv3

pragma solidity 0.8.27;

import { IERC20, SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ICurveVaultXChain } from "interfaces/stakedao/ICurveVaultXChain.sol";
import { IClaimRewardsXChain } from "interfaces/stakedao/IClaimRewardsXChain.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { StrategyAdapterHarvestable } from "src/abstracts/StrategyAdapterHarvestable.sol";
import { ICurveLiquidityPool } from "interfaces/curve/ICurveLiquidityPool.sol";
import { ICurveSlippageUtility } from "interfaces/infra/utilities/curve/ICurveSlippageUtility.sol";
import { IMultistrategy } from "interfaces/infra/multistrategy/IMultistrategy.sol";
import { MStrat } from "src/types/DataTypes.sol";
import { Errors } from "src/infra/libraries/Errors.sol";

contract CurveStableNgSDAdapter is StrategyAdapterHarvestable {
    using SafeERC20 for IERC20;
    using SafeCast for int128;
    using Math for uint256;

    struct CurveSNGSDData {
        address curveLiquidityPool;
        address sdVault;
        address sdRewards;
        address curveSlippageUtility;
        int128 assetIndex;
    }

    /// @notice Parts-per-million base; 1 000 000 ppm = 100 %.
    uint256 constant PPM_DENOMINATOR = 1_000_000;

    /// @notice The Curve Liquidity Pool where the asset will be deposited.
    ICurveLiquidityPool curveLiquidityPool;

    /// @notice The StakeDAO Vault where Curve Liquidity Pool shares will be deposited to earn rewards.
    ICurveVaultXChain public immutable stakeDAOVault;

    /// @notice The StakeDAO Claim rewards contract.
    IClaimRewardsXChain public immutable stakeDAORewards;

    /// @notice Utility contract to calculate the slippage when adding and removing liquidity.
    ICurveSlippageUtility public immutable curveSlippageUtility;

    /// @notice Address of the StakeDAO Vault Gauge
    address public immutable gauge;

    /// @notice Index of the asset in the coins array.
    int128 public immutable assetIndex;

    /// @notice Number of different coins in coins array.
    uint256 public immutable nCoins;

    /// @notice Slippage limit when withdrawing from the Curve Liquidity Pool.
    /// @dev If the slippage is higher than this parameter, the transaction will revert.
    uint256 public curveSlippageLimit;

    /// @notice Buffer uplift applied to LP burns to cover round-down. 1 ppm (+0.0001 %)
    /// @dev Only used before burning shares when withdrawing.
    uint256 public ppmSafetyFactor;

    /// @notice Thrown when the withdraw slippage is above the valid limit.
    /// @param slippage Expected slippage
    /// @param slippageLimit Slippage limit
    error CurveSlippageTooHigh(uint256 slippage, uint256 slippageLimit);

    /// @notice Thrown when the provided PPM value is out of the valid range.
    /// @param ppm The invalid PPM value that caused the error
    error InvalidPPM(uint256 ppm);

    /// @notice Constructor for the strategy adapter.
    /// @param _multistrategy The address of the multi-strategy contract.
    /// @param _asset The address of the asset.
    /// @param _harvestAddresses Struct of Protocol Addresses.
    /// @param _curveLPSDData Struct of Curve and StakeDAO Data.
    /// @param _name The name of this Strategy Adapter.
    /// @param _id The type identifier of this Strategy Adapter.
    constructor(
        address _multistrategy,
        address _asset,
        HarvestAddresses memory _harvestAddresses,
        CurveSNGSDData memory _curveLPSDData,
        string memory _name,
        string memory _id
    ) 
        StrategyAdapterHarvestable(_multistrategy, _asset, _harvestAddresses,_name, _id)
    {   
        curveLiquidityPool = ICurveLiquidityPool(_curveLPSDData.curveLiquidityPool);
        stakeDAOVault = ICurveVaultXChain(_curveLPSDData.sdVault);
        stakeDAORewards = IClaimRewardsXChain(_curveLPSDData.sdRewards);
        curveSlippageUtility = ICurveSlippageUtility(_curveLPSDData.curveSlippageUtility);
        assetIndex = _curveLPSDData.assetIndex;
        nCoins = curveLiquidityPool.N_COINS();
        gauge = stakeDAOVault.sdGauge();
        ppmSafetyFactor = PPM_DENOMINATOR + 1;
        _giveAllowances();
    }
    /*//////////////////////////////////////////////////////////////////////////
                            USER-FACING CONSTANT FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Estimates the slippage for depositing a given amount into the Curve liquidity pool
    /// @dev Delegates to the `curveSlippageUtility` to compute slippage based on the current pool state
    /// @param _amount The amount of the asset to simulate depositing, in asset decimals
    /// @return slippage The estimated slippage. (100 ether = 100%)
    /// @return positive Indicates whether the slippage is positive (true) or negative (false)
    function getDepositSlippage(uint256 _amount) public view returns (uint256 slippage, bool positive) {
        return curveSlippageUtility.getDepositSlippage(address(curveLiquidityPool), assetIndex, _amount);
    }

    /// @notice Estimates the slippage for withdrawing a given amount from the Curve liquidity pool
    /// @dev Delegates to the `curveSlippageUtility` to compute slippage based on the current pool state
    /// @param _amount The amount of the asset to simulate withdrawing, in asset decimals
    /// @return slippage The estimated slippage. (100 ether = 100%)
    /// @return positive Indicates whether the slippage is positive (true) or negative (false)
    function getWithdrawSlippage(uint256 _amount) public view returns (uint256 slippage, bool positive) {
        return curveSlippageUtility.getWithdrawSlippage(address(curveLiquidityPool), assetIndex, _amount);
    }

    /*//////////////////////////////////////////////////////////////////////////
                            INTERNAL CONSTANT FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Returns the total amount of assets held in this adapter.
    function _totalAssets() internal override view returns(uint256) {
        uint256 assetBalance = IERC20(asset).balanceOf(address(this));
        uint256 vaultShares = IERC20(gauge).balanceOf(address(this));

        if(vaultShares == 0) return assetBalance;

        uint256 assetsWithdrawable = curveLiquidityPool.calc_withdraw_one_coin(vaultShares, assetIndex);
        return assetsWithdrawable + assetBalance;
    }

    /// @inheritdoc StrategyAdapterHarvestable
    function _verifyRewardToken(address _token) internal view override {
        require(
            _token != address(curveLiquidityPool) &&
            _token != address(stakeDAOVault) && 
            _token != address(stakeDAORewards) &&
            _token != address(gauge),
            Errors.InvalidRewardToken(_token));
    }

    /*//////////////////////////////////////////////////////////////////////////
                        USER FACING NON-CONSTANT FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Sets the maximum allowed slippage limit for Curve operations
    /// @param _slippageLimit The new slippage limit, expressed in ether (100 ether = 100%)
    function setCurveSlippageLimit(uint256 _slippageLimit) external onlyOwner {
        require(_slippageLimit <= 100 ether, Errors.SlippageLimitExceeded(_slippageLimit));
        curveSlippageLimit = _slippageLimit;
    }

    /// @notice Sets the buffer for price impact protection as parts per million (PPM)
    /// @dev The PPM value represents parts per million and is used to adjust the number of LP shares needed when withdrawing.
    /// @param _ppm The PPM value to add to the base denominator for safety calculations
    function setBufferPPM(uint256 _ppm) external onlyOwner {
        require(_ppm > 0 && _ppm < 1_000, InvalidPPM(_ppm));
        ppmSafetyFactor = PPM_DENOMINATOR + _ppm;
    }

    /*//////////////////////////////////////////////////////////////////////////
                            INTERNAL NON-CONSTANT FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Deposits all the available base asset balance.
    function _deposit() internal override {
        uint256 balance = IERC20(asset).balanceOf(address(this));
        (uint256 slippage, bool positiveSlippage) = getDepositSlippage(balance);
        require(positiveSlippage || slippage <= curveSlippageLimit, CurveSlippageTooHigh(slippage, curveSlippageLimit));

        uint256[] memory amounts = new uint256[](nCoins);
        amounts[assetIndex.toUint256()] = balance;
        uint256 lpSharesAmount = curveLiquidityPool.add_liquidity(amounts, 0);
        stakeDAOVault.deposit(address(this), lpSharesAmount);
    }

    /// @notice Withdraws a specified amount of assets.
    /// @param _amount The amount of assets to withdraw.
    function _withdraw(uint256 _amount) internal override {
        (uint256 slippage, bool positiveSlippage) = getWithdrawSlippage(_amount);
        require(positiveSlippage || slippage <= curveSlippageLimit, CurveSlippageTooHigh(slippage, curveSlippageLimit));

        uint256[] memory amounts = new uint256[](nCoins);
        amounts[assetIndex.toUint256()] = _amount;
        uint256 lpSharesNeeded = curveLiquidityPool.calc_token_amount(amounts, false);
        uint256 lpSharesBalance = IERC20(gauge).balanceOf(address(this));

        lpSharesNeeded = _amount >= _getMinDebtDelta() ? lpSharesNeeded.mulDiv(ppmSafetyFactor, PPM_DENOMINATOR) : lpSharesNeeded *= 2;

        uint256 lpShares = Math.min(lpSharesNeeded, lpSharesBalance);
        stakeDAOVault.withdraw(lpShares);
        if(lpSharesNeeded > lpSharesBalance) {
            curveLiquidityPool.remove_liquidity_one_coin(lpShares, assetIndex, 0);
        } else {
            curveLiquidityPool.remove_liquidity_one_coin(lpShares, assetIndex, _amount);
        }
    }

    /// @notice Performs an emergency withdrawal of all assets from StakeDAO and Curve.
    /// This function is intended for emergency situations where all assets need to be withdrawn immediately.
    /// @dev The other non-asset tokens will be sent to the owner of this contract.
    function _emergencyWithdraw() internal override {
        stakeDAOVault.withdrawAll();
        uint256 lpShares = curveLiquidityPool.balanceOf(address(this));

        if(lpShares > 0) {
            uint256[] memory minAmounts = new uint256[](nCoins);
            curveLiquidityPool.remove_liquidity(lpShares, minAmounts);
        }

        for(uint256 i = 0; i < nCoins; ++i) {
            address token = curveLiquidityPool.coins(i);
            if (token != asset) {
                uint256 tokenBalance = IERC20(token).balanceOf(address(this));
                IERC20(token).transfer(owner(), tokenBalance);
            }
        }
    }

    /// @notice Sets the maximum allowance of the base asset for the Curve Liquidity Pool.
    /// and sets the maximum allowance of Curve Liquidity Pool shares for StakeDAO
    function _giveAllowances() internal override {
        IERC20(asset).forceApprove(address(curveLiquidityPool), type(uint).max);
        IERC20(curveLiquidityPool).forceApprove(address(stakeDAOVault), type(uint).max);
        IERC20(wrappedGas).forceApprove(swapper, type(uint).max);
    }

    /// @notice Revokes all the allowances.
    function _revokeAllowances() internal override {
        IERC20(asset).forceApprove(address(curveLiquidityPool), 0);
        IERC20(curveLiquidityPool).forceApprove(address(stakeDAOVault), 0);
        IERC20(wrappedGas).forceApprove(swapper, 0);
    }

    /// @inheritdoc StrategyAdapterHarvestable
    function _claim() internal override {
        address[] memory gauges = new address[](1);
        gauges[0] = gauge;
        stakeDAORewards.claimRewards(gauges);
    }

    /// @notice Returns this adapter's minimum debt delta.
    function _getMinDebtDelta() internal view returns (uint256 minDebtDelta) {
        MStrat.StrategyParams memory params = IMultistrategy(multistrategy).getStrategyParameters(address(this));
        minDebtDelta = params.minDebtDelta;
    }
}