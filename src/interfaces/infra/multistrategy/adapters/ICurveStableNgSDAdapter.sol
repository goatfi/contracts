// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface ICurveStableNgSDAdapter {
    function getDepositSlippage(uint256 _amount) external view returns (uint256 slippage, bool positive);
    function getWithdrawSlippage(uint256 _amount) external view returns (uint256 slippage, bool positive);
    function curveSlippageLimit() external view returns (uint256 slippageLimit);
    function ppmSafetyFactor() external view returns (uint256);
    function setCurveSlippageLimit(uint256 _slippageLimit) external;
    function setBufferPPM(uint256 _ppm) external;
}