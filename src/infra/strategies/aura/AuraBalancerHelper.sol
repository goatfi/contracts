// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IBalancerPool, IBalancerVault, IERC20} from "interfaces/aura/IBalancer.sol";

contract AuraBalancerHelper {
    using SafeERC20 for IERC20;

    address private immutable swapper;
    address private immutable balVault;

    /// @notice Caller not valid
    /// @param swapper Address of the swapper
    /// @param caller Address of the caller
    error InvalidCaller(address swapper, address caller);

    constructor(address _swapper, address _vault) {
        swapper = _swapper;
        balVault = _vault;
    }

    function addBalancerLiquidity(
        bytes32 poolId,
        uint256 amount,
        uint256 tokenCount,
        uint256 depositIndex
    ) external {
        if (msg.sender != swapper) revert InvalidCaller(swapper, msg.sender);

        (IERC20[] memory tokens, , ) = IBalancerVault(balVault).getPoolTokens(
            poolId
        );

        uint[] memory amounts = new uint[](tokens.length);
        amounts[depositIndex] = amount;

        // transfer tokens first
        IERC20(address(tokens[depositIndex])).safeTransferFrom(
            msg.sender,
            address(this),
            amount
        );

        amounts[depositIndex] = amount;

        uint256[] memory amounts1 = new uint256[](tokenCount);
        amounts1[depositIndex] = amount;
        bytes memory userData = abi.encode(1, amounts1, 0);

        IBalancerVault.JoinPoolRequest memory request = IBalancerVault
            .JoinPoolRequest({
                assets: tokens,
                maxAmountsIn: amounts,
                userData: userData,
                fromInternalBalance: false
            });

        // approve token
        tokens[depositIndex].approve(balVault, amount);

        IBalancerVault(balVault).joinPool(
            poolId,
            address(this),
            swapper,
            request
        );
    }
}
