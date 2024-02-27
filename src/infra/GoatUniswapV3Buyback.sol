// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import { IERC20, SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ISwapRouter } from "@uniswapV3-periphery/interfaces/ISwapRouter.sol";

contract GoatUniswapV3Buyback {
    using SafeERC20 for IERC20;

    /// @notice Uniswap V3 Router
    ISwapRouter constant router = ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);

    /// @notice wstGOA strategy address
    address immutable goatStrategy;

    /// @notice GOA has been bought
    /// @param amountIn Amount spent buying GOA
    /// @param amountOut Amount of GOA bought
    event BuyBack(uint256 amountIn, uint256 amountOut);
    /// @notice Caller not valid
    error InvalidCaller();
    // @notice Address is address(0)
    error ZeroAddress();

    constructor(address _goatStrategy) {
        goatStrategy = _goatStrategy;
    }

    /// @notice Swap amountIn of tokenIn to tokenOut
    /// @param tokenIn Token to swap from
    /// @param tokenOut Token to swap to
    /// @param amountIn Amount of tokenIn to swap
    function swap(
        address tokenIn,
        address tokenOut,
        uint amountIn
    ) external returns (uint amountOut) {
        if(msg.sender != goatStrategy) revert InvalidCaller();
        if(tokenIn == address(0) || tokenOut == address(0)) revert ZeroAddress();

        IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), amountIn);
        IERC20(tokenIn).safeIncreaseAllowance(address(router), amountIn);

        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter
            .ExactInputSingleParams({
                tokenIn: tokenIn,
                tokenOut: tokenOut,
                fee: 3000,
                recipient: msg.sender,
                deadline: block.timestamp,
                amountIn: amountIn,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            });

        amountOut = router.exactInputSingle(params);
        emit BuyBack(amountIn, amountOut);
    }
}