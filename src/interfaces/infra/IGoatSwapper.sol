// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IGoatSwapper {
    function swap(
        address fromToken,
        address toToken,
        uint256 amountIn
    ) external returns (uint256 amountOut);

    function swap(
        address fromToken,
        address toToken,
        uint256 amountIn,
        uint256 minAmountOut
    ) external returns (uint256 amountOut);

    function getAmountOut(
        address _fromToken,
        address _toToken,
        uint256 _amountIn
    ) external view returns (uint256 amountOut);

    struct SwapInfo {
        address router;
        bytes data;
        uint256 amountIndex;
    }

    function setSwapInfo(
        address _fromToken, 
        address _toToken, 
        SwapInfo calldata _swapInfo
    ) external;

    function setSwapInfos(
        address[] calldata _fromTokens, 
        address[] calldata _toTokens, 
        SwapInfo[] calldata _swapInfos
    ) external;
}