// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { SafeERC20, IERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IBalancerPool, IBalancerVault } from "interfaces/aura/IBalancer.sol";

contract AuraBalancerHelper {
    using SafeERC20 for IERC20;

    address private immutable swapper;
    address private immutable balancerVault;

    /// @notice Caller not valid
    /// @param swapper Address of the swapper
    /// @param caller Address of the caller
    error InvalidCaller(address swapper, address caller);

    constructor(address _swapper, address _vault) {
        swapper = _swapper;
        balancerVault = _vault;
    }

    /// @notice Adds liquidity to a Balancer pool
    /// @param _poolId The identifier of the Balancer pool
    /// @param _amount The amount of the token to deposit
    /// @param _tokenCount The total number of different tokens in the pool
    /// @param _depositIndex The index of the token in the pool's array to deposit
    function addBalancerLiquidity(
        bytes32 _poolId,
        uint256 _amount,
        uint256 _tokenCount,
        uint256 _depositIndex
    ) external {
        if (msg.sender != swapper) revert InvalidCaller(swapper, msg.sender);

        (IERC20[] memory tokens, , ) = IBalancerVault(balancerVault).getPoolTokens(_poolId);
        IERC20(address(tokens[_depositIndex])).safeTransferFrom(msg.sender, address(this), _amount);

        uint256[] memory amountsIn = new uint256[](tokens.length);
        uint256[] memory userDataAmounts = new uint256[](_tokenCount);
        amountsIn[_depositIndex] = _amount;
        userDataAmounts[_depositIndex] = _amount;

        bytes memory userData = abi.encode(1, userDataAmounts, 0);

        IBalancerVault.JoinPoolRequest memory request = IBalancerVault
            .JoinPoolRequest({
                assets: tokens,
                maxAmountsIn: amountsIn,
                userData: userData,
                fromInternalBalance: false
            });

        tokens[_depositIndex].safeIncreaseAllowance(balancerVault, _amount);

        IBalancerVault(balancerVault).joinPool(
            _poolId,
            address(this),
            swapper,
            request
        );
    }
}
