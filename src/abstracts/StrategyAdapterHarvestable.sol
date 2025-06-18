// SPDX-License-Identifier: GNU AGPLv3

pragma solidity 0.8.27;

import { IERC20, SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IStrategyAdapterHarvestable } from "interfaces/infra/multistrategy/IStrategyAdapterHarvestable.sol";
import { IGoatSwapper } from "interfaces/infra/IGoatSwapper.sol";
import { StrategyAdapter } from "src/abstracts/StrategyAdapter.sol";
import { Errors } from "src/infra/libraries/Errors.sol";

abstract contract StrategyAdapterHarvestable is IStrategyAdapterHarvestable, StrategyAdapter {
    using SafeERC20 for IERC20;

    struct HarvestAddresses {
        address swapper;
        address wrappedGas;
    }
    
    /// @notice The timestamp of the last successful harvest.
    uint256 public lastHarvest;

    /// @notice An array of reward token addresses that can be claimed and swapped.
    address[] public rewards;

    /// @notice The address of the Wrapped Gas token used as an intermediary for swaps.
    /// Used because it has high liquidity.
    address internal wrappedGas;

    /// @notice The address of the swapper contract used to swap reward tokens.
    address internal swapper;

    /// @notice A mapping of minimum amounts for each reward token before it can be swapped.
    /// @dev The key is the reward token address, and the value is the minimum amount required for swapping.
    mapping(address token => uint minimumAmount) public minimumAmounts;

    /*//////////////////////////////////////////////////////////////////////////
                                     CONSTRUCTOR
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Constructor for the strategy adapter.
    /// @param _multistrategy The address of the multi-strategy contract.
    /// @param _asset The address of the asset.
    /// @param _harvestAddresses Struct of Protocol Addresses.
    /// @param _name The name of this Strategy Adapter.
    /// @param _id The type identifier of this Strategy Adapter.
    constructor(
        address _multistrategy,
        address _asset,
        HarvestAddresses memory _harvestAddresses,
        string memory _name,
        string memory _id
    ) 
        StrategyAdapter(_multistrategy, _asset, _name, _id)
    {
        swapper = _harvestAddresses.swapper;
        wrappedGas = _harvestAddresses.wrappedGas;
    }

    /*//////////////////////////////////////////////////////////////////////////
                        USER FACING CONSTANT FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @inheritdoc IStrategyAdapterHarvestable
    function rewardsLength() external view returns (uint256) {
        return rewards.length;
    }

    /*//////////////////////////////////////////////////////////////////////////
                        USER FACING NON-CONSTANT FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @inheritdoc IStrategyAdapterHarvestable
    function harvest() external whenNotPaused {
        _claim();
        _swapRewardsToWrappedGas();
        if (IERC20(wrappedGas).balanceOf(address(this)) > minimumAmounts[wrappedGas]) {
            _swapWrappedGasToAsset();
            uint256 assetsHarvested = _balance();
            _deposit();
            lastHarvest = block.timestamp;

            emit AdapterHarvested(msg.sender, assetsHarvested, _totalAssets());
        }
    }

    /// @inheritdoc IStrategyAdapterHarvestable
    function addReward(address _token) external onlyOwner {
        require(_token != asset && _token != wrappedGas, Errors.InvalidRewardToken(_token));
        _verifyRewardToken(_token);

        rewards.push(_token);
        IERC20(_token).forceApprove(swapper, type(uint256).max);
    }

    /// @inheritdoc IStrategyAdapterHarvestable
    function resetRewards() external onlyOwner {
        for (uint i; i < rewards.length; ++i) {
            IERC20(rewards[i]).forceApprove(swapper, 0);
        }
        delete rewards;
    }

    /// @inheritdoc IStrategyAdapterHarvestable
    function setRewardMinimumAmount(address _token, uint _minAmount) external onlyOwner {
        minimumAmounts[_token] = _minAmount;
    }

    /// @inheritdoc IStrategyAdapterHarvestable
    function updateSwapper(address _swapper) external onlyOwner {
        for (uint i; i < rewards.length; ++i) {
            address token = rewards[i];
            IERC20(token).forceApprove(swapper, 0);
            IERC20(token).forceApprove(_swapper, type(uint256).max);
        }
        IERC20(wrappedGas).forceApprove(swapper, 0);
        IERC20(wrappedGas).forceApprove(_swapper, type(uint256).max);
        swapper = _swapper;
        emit SwapperUpdated(_swapper);
    }

    /*//////////////////////////////////////////////////////////////////////////
                            INTERNAL NON-CONSTANT FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Swaps all reward tokens to Wrapped Gas.
    /// @dev This function checks if the balance of each reward token exceeds the minimum amount before swapping.
    function _swapRewardsToWrappedGas() internal virtual {
        for (uint i; i < rewards.length; ++i) {
            address token = rewards[i];
            uint256 amount = IERC20(token).balanceOf(address(this));
            if (amount > minimumAmounts[token]) {
                _swap(token, wrappedGas);
            }
        }
    }

    /// @notice Swaps Wrapped Gas to `asset`.
    function _swapWrappedGasToAsset() internal virtual {
        if (asset != wrappedGas) _swap(wrappedGas, asset);
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