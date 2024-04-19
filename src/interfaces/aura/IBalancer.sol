// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

interface IAsset {}

interface IBalancerVault {
    enum SwapKind {
        GIVEN_IN,
        GIVEN_OUT
    }

    struct JoinPoolRequest {
        IAsset[] assets;
        uint256[] maxAmountsIn;
        bytes userData;
        bool fromInternalBalance;
    }

    struct SingleSwap {
        bytes32 poolId;
        SwapKind kind;
        IAsset assetIn;
        IAsset assetOut;
        uint256 amount;
        bytes userData;
    }

    struct FundManagement {
        address sender;
        bool fromInternalBalance;
        address payable recipient;
        bool toInternalBalance;
    }

    function swap(
        SingleSwap memory singleSwap,
        FundManagement memory funds,
        uint256 limit,
        uint256 deadline
    ) external payable returns (uint256 amountCalculated);
}

interface IBalancerPool {
    function getPoolId() external view returns (bytes32);
}
