// SPDX-License-Identifier: GNU AGPLv3
pragma solidity 0.8.27;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { ICurveLiquidityPool } from "interfaces/curve/ICurveLiquidityPool.sol";
import { ICurveSlippageUtility } from "interfaces/infra/utilities/curve/ICurveSlippageUtility.sol";
import { Errors } from "src/infra/libraries/Errors.sol";

abstract contract CurveLPBase is Ownable {
    /// @notice Parts-per-million base; 1 000 000 ppm = 100 %.
    uint256 constant PPM_DENOMINATOR = 1_000_000;
    
    /// @notice The Curve Liquidity Pool where the asset will be deposited.
    ICurveLiquidityPool public immutable curveLiquidityPool;

    /// @notice Utility contract to calculate the slippage when adding and removing liquidity.
    ICurveSlippageUtility public immutable curveSlippageUtility;

    /// @notice Index of the asset in the coins array.
    uint256 public immutable assetIndex;

    /// @notice Slippage limit when withdrawing from the Curve Liquidity Pool.
    /// @dev If the slippage is higher than this parameter, the transaction will revert.
    uint256 public curveSlippageLimit;

    /// @notice Buffer uplift applied to LP burns to cover round-down. 1 ppm (+0.0001 %)
    /// @dev Only used before burning shares when withdrawing.
    uint256 public withdrawBuffer;

    /// @notice Thrown when the withdraw slippage is above the valid limit.
    /// @param slippage Expected slippage
    /// @param slippageLimit Slippage limit
    error CurveSlippageTooHigh(uint256 slippage, uint256 slippageLimit);

    /// @notice Thrown when the provided PPM value is out of the valid range.
    /// @param ppm The invalid PPM value that caused the error
    error InvalidPPM(uint256 ppm);

    /// @notice Constructor for the strategy adapter.
    /// @param _curveLiquidityPool Address of the curve liquidity pool.
    /// @param _curveSlippageUtility Address of the slippage calculation utility for thy pool type.
    constructor(address _curveLiquidityPool, address _curveSlippageUtility) {
        curveLiquidityPool = ICurveLiquidityPool(_curveLiquidityPool);
        curveSlippageUtility = ICurveSlippageUtility(_curveSlippageUtility);
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
                        USER FACING NON-CONSTANT FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Sets the maximum allowed slippage limit for Curve operations
    /// @param _slippageLimit The new slippage limit, expressed in ether (100 ether = 100%)
    function setCurveSlippageLimit(uint256 _slippageLimit) external onlyOwner {
        require(_slippageLimit <= 100 ether, Errors.SlippageLimitExceeded(_slippageLimit));
        curveSlippageLimit = _slippageLimit;
    }

    /// @notice Sets the withdraw buffer
    /// @dev The PPM value represents parts per million. Limited to (+0.0001 % - +0.1 %)
    /// @param _ppm The PPM value to add to the base denominator for safety calculations
    function setWithdrawBufferPPM(uint256 _ppm) external onlyOwner {
        require(_ppm > 0 && _ppm < 1_000, InvalidPPM(_ppm));
        withdrawBuffer = PPM_DENOMINATOR + _ppm;
    }
}