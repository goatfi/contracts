// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { SafeERC20, IERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IvRouter } from "interfaces/virtuswap/IVRouter.sol";
import { IvPair } from "interfaces/virtuswap/IvPair.sol";
import { IvPairFactory } from "interfaces/virtuswap/IvPairFactory.sol";

contract VirtuswapOneSidedLiquidity {
    using SafeERC20 for IERC20;

    address private immutable swapper;
    address private immutable factory;
    address private immutable router;

    /// @notice Caller not valid
    /// @param swapper Address of the swapper
    /// @param caller Address of the caller
    error InvalidCaller(address swapper, address caller);
    /// @notice Amount to add liquidity is insufficient
    /// @param amount Amount to be added as liquidity
    error InsufficientAmount(uint256 amount);

    constructor(address _swapper, address _factory, address _router) {
        swapper = _swapper;
        factory = _factory;
        router = _router;
    }

    /// @notice Calculate the square root
    /// @param y number to calculate the square root of
    function sqrt(uint256 y) private pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }

    /// @notice Calculates the amount to swap to the other asset in the pool in order
    /// to add the maximum amount of liquidity
    /// @param r Reserve of the asset in the pool
    /// @param a Amount of the asset to be added as liquidty
    function getSwapAmount(uint256 r, uint256 a) public pure returns (uint256) {
        return (sqrt(r * (r * 3988009 + a * 3988000)) - r * 1997) / 1994;
    }

    /// @notice Add liquidty one sided with tokenA on a LP formed of tokenA and tokenB
    /// @param _tokenA TokenA of the LP
    /// @param _tokenB TokenB of the LP
    /// @param _amountA Amount of TokenA that will be added as liquidity on the LP
    function addLiquidityOneSided(address _tokenA, address _tokenB, uint256 _amountA) external {
        if (msg.sender != swapper) revert InvalidCaller(swapper, msg.sender);
        if (_amountA <= 1) revert InsufficientAmount(_amountA);

        IERC20(_tokenA).safeTransferFrom(msg.sender, address(this), _amountA);

        address pair = IvPairFactory(factory).pairs(_tokenA, _tokenB);
        (uint256 reserve0, uint256 reserve1) =
            IvPair(pair).getBalances();

        uint256 swapAmount;
        if (IvPair(pair).token0() == _tokenA) {
            // swap from token0 to token1
            swapAmount = getSwapAmount(reserve0, _amountA);
        } else {
            // swap from token1 to token0
            swapAmount = getSwapAmount(reserve1, _amountA);
        }

        _swap(_tokenA, _tokenB, swapAmount);
        _addLiquidity(_tokenA, _tokenB, msg.sender);
    }

    /// @notice Swaps _amount of _from token to _to token
    /// @param _from Token to swap from
    /// @param _to Token to swap to
    /// @param _amount The amount of _from to swap to _to
    function _swap(address _from, address _to, uint256 _amount) internal {
        IERC20(_from).approve(router, _amount);

        address[] memory path = new address[](2);
        path = new address[](2);
        path[0] = _from;
        path[1] = _to;

        IvRouter(router).swapExactTokensForTokens(
            path, _amount, 1, address(this), block.timestamp
        );
    }

    /// @notice Add liquidity to a Virtuswap LP
    /// @param _tokenA TokenA of the LP
    /// @param _tokenB TokenB of the LP
    /// @param _recipient Who will receive the LP tokens
    function _addLiquidity(address _tokenA, address _tokenB, address _recipient) internal {
        uint256 balA = IERC20(_tokenA).balanceOf(address(this));
        uint256 balB = IERC20(_tokenB).balanceOf(address(this));
        IERC20(_tokenA).approve(router, balA);
        IERC20(_tokenB).approve(router, balB);

        IvRouter(router).addLiquidity(_tokenA, _tokenB, balA, balB, 0, 0, _recipient, block.timestamp);
    }
}