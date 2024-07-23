// SPDX-License-Identifier: GNU AGPLv3

pragma solidity >=0.8.20 <= 0.9.0;

import { IERC20, SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { IGoatVault } from "interfaces/infra/IGoatVault.sol";
import { StrategyAdapter } from "src/abstracts/StrategyAdapter.sol";

contract GoatProtocolStrategyAdapter is StrategyAdapter {
    using SafeERC20 for IERC20;

    /// @notice Address of the GoatVault this strategy adapter will deposit into.
    address goatVault;

    /*//////////////////////////////////////////////////////////////////////////
                                     CONSTRUCTOR
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Constructor for the strategy adapter.
    /// 
    /// This constructor performs the following actions:
    /// - Initializes the StrategyAdapter with the provided multi-strategy and base asset addresses.
    /// - Sets the GoatVault address.
    /// 
    /// @param _multistrategy The address of the multi-strategy contract.
    /// @param _baseAsset The address of the base asset token.
    /// @param _goatVault The address of the GoatVault.
    constructor(
        address _multistrategy,
        address _baseAsset,
        address _goatVault
    ) 
        StrategyAdapter(_multistrategy, _baseAsset)
    {
        goatVault = _goatVault;
    }

    /*//////////////////////////////////////////////////////////////////////////
                            INTERNAL CONSTANT FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Internal view function to calculate the total assets held by the contract in the GoatVault.
    /// 
    /// This function performs the following actions:
    /// - Retrieves the price per share from the GoatVault.
    /// - Retrieves the GoatVault share balance of this contract.
    /// - Calculates the total assets by multiplying the share balance by the price per share, and scaling by 1 ether.
    /// 
    /// @return The total assets held by this contract in the GoatVault.
    function _totalAssets() internal override view returns(uint256) {
        uint256 pricePerShare = IGoatVault(goatVault).getPricePerFullShare();
        uint256 shareBalance = IERC20(goatVault).balanceOf(address(this));

        return Math.mulDiv(shareBalance, pricePerShare, 1 ether);
    }

    /// @notice Internal view function to convert an amount of assets to shares based on the GoatVault's price per share.
    /// 
    /// This function performs the following actions:
    /// - Retrieves the price per share from the GoatVault.
    /// - Converts the given amount of assets to shares by dividing the amount by the price per share and scaling by 1 ether.
    /// 
    /// @param _amount The amount of assets to convert to shares.
    /// @return The number of shares corresponding to the given amount of assets.
    function _convertToShares(uint256 _amount) internal view returns(uint256) {
        uint256 pricePerShare = IGoatVault(goatVault).getPricePerFullShare();
        return Math.mulDiv(_amount, 1 ether, pricePerShare);
    }

    /*//////////////////////////////////////////////////////////////////////////
                            INTERNAL NON-CONSTANT FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Internal function to deposit into into the GoatVault.
    /// 
    /// This function performs the following actions:
    /// - Retrieves the current balance of the base asset held by the contract.
    /// - Deposits the entire base asset balance into the GoatVault.
    function _deposit() internal override {
        uint256 baseAssetBalance = IERC20(baseAsset).balanceOf(address(this));
        IGoatVault(goatVault).deposit(baseAssetBalance);
    }

    /// @notice Internal function to withdraw a specified amount of assets from the GoatVault.
    /// 
    /// This function performs the following actions:
    /// - Converts the given amount of assets to the equivalent number of shares.
    /// - Withdraws the calculated number of shares from the GoatVault.
    /// 
    /// @param _amount The amount of assets to withdraw from the GoatVault.
    function _withdraw(uint256 _amount) internal override {
        uint256 shares = _convertToShares(_amount);
        IGoatVault(goatVault).withdraw(shares);
    }

    /// @notice Internal function to set the maximum allowance of the base asset for the GoatVault.
    /// 
    /// This function performs the following actions:
    /// - Grants the GoatVault an unlimited allowance to spend the base asset held by the contract.
    function _giveAllowances() internal override {
        IERC20(baseAsset).forceApprove(goatVault, type(uint256).max);
    }

    /// @notice Internal function to revoke the allowance of the base asset for the GoatVault.
    /// 
    /// This function performs the following actions:
    /// - Sets the allowance of the base asset for the GoatVault to zero, effectively revoking any previous allowances.
    function _revokeAllowances() internal override {
        IERC20(baseAsset).forceApprove(goatVault, 0);
    }
}