// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
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
    /// @param poolId The identifier of the Balancer pool
    /// @param amount The amount of the token to deposit
    /// @param tokenCount The total number of different tokens in the pool
    /// @param depositIndex The index of the token in the pool's array to deposit
    function addBalancerLiquidity(
        bytes32 poolId,
        uint256 amount,
        uint256 tokenCount,
        uint256 depositIndex
    ) external {
        if (msg.sender != swapper) revert InvalidCaller(swapper, msg.sender);

        (IERC20[] memory tokens, , ) = IBalancerVault(balancerVault).getPoolTokens(poolId);
        IERC20(address(tokens[depositIndex])).safeTransferFrom(msg.sender, address(this), amount);

        uint256[] memory amounts = new uint256[](tokens.length);
        uint256[] memory amounts1 = new uint256[](tokenCount);
        amounts[depositIndex] = amount;
        amounts1[depositIndex] = amount;
        bytes memory userData = abi.encode(1, amounts1, 0);

        IBalancerVault.JoinPoolRequest memory request = IBalancerVault
            .JoinPoolRequest({
                assets: tokens,
                maxAmountsIn: amounts,
                userData: userData,
                fromInternalBalance: false
            });

        tokens[depositIndex].safeIncreaseAllowance(balancerVault, amount);

        IBalancerVault(balancerVault).joinPool(
            poolId,
            address(this),
            swapper,
            request
        );
    }
}
