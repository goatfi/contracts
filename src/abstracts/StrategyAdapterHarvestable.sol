// SPDX-License-Identifier: GNU AGPLv3

pragma solidity 0.8.27;

import { IERC20, SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IStrategyAdapterHarvestable } from "interfaces/infra/multistrategy/IStrategyAdapterHarvestable.sol";
import { IGoatSwapper } from "interfaces/infra/IGoatSwapper.sol";
import { StrategyAdapter } from "src/abstracts/StrategyAdapter.sol";
import { Errors } from "src/infra/libraries/Errors.sol";

abstract contract StrategyAdapterHarvestable is IStrategyAdapterHarvestable, StrategyAdapter {
    using SafeERC20 for IERC20;

    struct ProtocolAddresses {
        address swapper;
        address weth;
    }

    /// @notice The address of the swapper contract used to swap reward tokens.
    address swapper;

    /// @notice The address of the WETH token used as an intermediary for swaps.
    address weth;

    /// @notice The timestamp of the last successful harvest.
    uint256 lastHarvest;

    /// @notice An array of reward token addresses that can be claimed and swapped.
    address[] public rewardsToClaim;

    /// @notice A mapping of minimum amounts for each reward token before it can be swapped.
    /// @dev The key is the reward token address, and the value is the minimum amount required for swapping.
    mapping(address token => uint minimumAmount) public minimumAmounts;

    /*//////////////////////////////////////////////////////////////////////////
                                     CONSTRUCTOR
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Constructor for the strategy adapter.
    /// @param _multistrategy The address of the multi-strategy contract.
    /// @param _asset The address of the asset.
    /// @param _protocolAddresses Struct of Protocol Addresses.
    /// @param _name The name of this Strategy Adapter.
    /// @param _id The type identifier of this Strategy Adapter.
    constructor(
        address _multistrategy,
        address _asset,
        ProtocolAddresses memory _protocolAddresses,
        string memory _name,
        string memory _id
    ) 
        StrategyAdapter(_multistrategy, _asset, _name, _id)
    {
        swapper = _protocolAddresses.swapper;
        weth = _protocolAddresses.weth;
    }

    /*//////////////////////////////////////////////////////////////////////////
                        USER FACING NON-CONSTANT FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @inheritdoc IStrategyAdapterHarvestable
    function harvest() external whenNotPaused {
        _claim();
        _swapRewardsToWETH();
        if (IERC20(weth).balanceOf(address(this)) > minimumAmounts[weth]) {
            _swapWETHToAsset();
            uint256 assetsHarvested = IERC20(asset).balanceOf(address(this));
            _deposit();
            lastHarvest = block.timestamp;

            emit AdapterHarvested(msg.sender, assetsHarvested, _totalAssets());
        }
    }

    /// @inheritdoc IStrategyAdapterHarvestable
    function addReward(address _token) external onlyOwner {
        require(_token != asset && _token != weth, Errors.InvalidRewardToken(_token));
        _verifyRewardToken(_token);

        rewardsToClaim.push(_token);
        IERC20(_token).forceApprove(swapper, type(uint256).max);
    }

    /// @inheritdoc IStrategyAdapterHarvestable
    function resetRewards() external onlyOwner {
        for (uint i; i < rewardsToClaim.length; ++i) {
            IERC20(rewardsToClaim[i]).forceApprove(swapper, 0);
        }
        delete rewardsToClaim;
    }

    /// @inheritdoc IStrategyAdapterHarvestable
    function setRewardMinimumAmount(address _token, uint _minAmount) external onlyOwner {
        minimumAmounts[_token] = _minAmount;
    }

    /// @inheritdoc IStrategyAdapterHarvestable
    function updateSwapper(address _swapper) external onlyOwner {
        for (uint i; i < rewardsToClaim.length; ++i) {
            address token = rewardsToClaim[i];
            IERC20(token).forceApprove(swapper, 0);
            IERC20(token).forceApprove(_swapper, type(uint256).max);
        }
        IERC20(weth).forceApprove(swapper, 0);
        IERC20(weth).forceApprove(_swapper, type(uint256).max);
        swapper = _swapper;
        emit SwapperUpdated(_swapper);
    }

    /*//////////////////////////////////////////////////////////////////////////
                            INTERNAL NON-CONSTANT FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Swaps all reward tokens to WETH.
    /// @dev This function checks if the balance of each reward token exceeds the minimum amount before swapping.
    function _swapRewardsToWETH() internal virtual {
        for (uint i; i < rewardsToClaim.length; ++i) {
            address token = rewardsToClaim[i];
            uint256 amount = IERC20(token).balanceOf(address(this));
            if (amount > minimumAmounts[token]) {
                IGoatSwapper(swapper).swap(token, weth, amount);
            }
        }
    }

    /// @notice Swaps WETH to `asset`.
    function _swapWETHToAsset() internal virtual {
        if (asset != weth) _swap(weth, asset);
    }

    /// @notice Swaps one token for another using the swapper contract.
    /// @param tokenFrom The address of the token to swap from.
    /// @param tokenTo The address of the token to swap to.
    function _swap(address tokenFrom, address tokenTo) internal {
        uint amount = IERC20(tokenFrom).balanceOf(address(this));
        IGoatSwapper(swapper).swap(tokenFrom, tokenTo, amount);
    }

    /// @notice Claims rewards.
    /// @dev This function is meant to be overridden by child contracts to implement reward claiming logic.
    function _claim() internal virtual {}

    /// @notice Verifies if a token is a valid reward token.
    /// @dev This function is meant to be overridden by child contracts to implement token verification logic.
    /// @param _token The address of the token to verify.
    function _verifyRewardToken(address _token) internal view virtual {}
}