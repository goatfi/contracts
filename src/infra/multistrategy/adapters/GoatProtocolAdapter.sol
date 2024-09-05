// SPDX-License-Identifier: GNU AGPLv3

pragma solidity >=0.8.20 <= 0.9.0;

import { IERC20, SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { IGoatVault } from "interfaces/infra/IGoatVault.sol";
import { StrategyAdapter } from "src/abstracts/StrategyAdapter.sol";
import { Errors } from "src/infra/libraries/Errors.sol";

contract GoatProtocolStrategyAdapter is StrategyAdapter {
    using SafeERC20 for IERC20;
    using Math for uint256;

    /// @notice Address of the GoatVault this strategy adapter will deposit into.
    address public immutable goatVault;

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
    /// @param _asset The address of the asset.
    /// @param _goatVault The address of the GoatVault.
    constructor(
        address _multistrategy,
        address _asset,
        address _goatVault,
        string memory _name,
        string memory _id
    ) 
        StrategyAdapter(_multistrategy, _asset, _name, _id)
    {   
        if(_goatVault == address(0)) {
            revert Errors.ZeroAddress();
        }
        goatVault = _goatVault;
        _giveAllowances();
    }

    /*//////////////////////////////////////////////////////////////////////////
                            INTERNAL CONSTANT FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

   /// @notice Calculates the total assets held by the contract.
    /// 
    /// This function performs the following actions:
    /// - Retrieves the current price per share from the GoatVault.
    /// - Retrieves the balance of GoatVault shares held by the contract.
    /// - Retrieves the balance of the asset held by the contract.
    /// - Calculates the value of the GoatVault shares in terms of the asset, using floor rounding.
    /// - Adds the asset balance to the value of the GoatVault shares to determine the total assets.
    /// 
    /// @return The total assets held by the contract, including both GoatVault shares and the asset balance.
    function _totalAssets() internal override view returns(uint256) {
        uint256 pricePerShare = IGoatVault(goatVault).getPricePerFullShare();
        uint256 sharesBalance = IERC20(goatVault).balanceOf(address(this));
        uint256 assetBalance = IERC20(asset).balanceOf(address(this));

        return sharesBalance.mulDiv(pricePerShare, 1 ether, Math.Rounding.Floor) + assetBalance;
    }

    /// @notice Converts an amount of assets to shares based on the GoatVault's price per share.
    /// 
    /// This function performs the following actions:
    /// - Retrieves the price per share from the GoatVault.
    /// - Converts the given amount of assets to shares by dividing the amount by the price per share and scaling by 1 ether.
    /// 
    /// @param _amount The amount of assets to convert to shares.
    /// @return The number of shares corresponding to the given amount of assets.
    function _convertToShares(uint256 _amount) internal view returns(uint256) {
        uint256 pricePerShare = IGoatVault(goatVault).getPricePerFullShare();
        return _amount.mulDiv(1 ether, pricePerShare, Math.Rounding.Ceil);
    }

    /*//////////////////////////////////////////////////////////////////////////
                            INTERNAL NON-CONSTANT FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Deposits into into the GoatVault.
    /// 
    /// This function performs the following actions:
    /// - Retrieves the current balance of the base asset held by the contract.
    /// - Deposits the entire base asset balance into the GoatVault.
    function _deposit() internal override {
        uint256 assetBalance = IERC20(asset).balanceOf(address(this));
        IGoatVault(goatVault).deposit(assetBalance);
    }

    /// @notice Withdraws a specified amount of assets from the GoatVault.
    /// 
    /// This function performs the following actions:
    /// - Converts the given amount of assets to the equivalent number of shares.
    /// - Withdraws the calculated number of shares from the GoatVault.
    /// 
    /// @param _amount The amount of assets to withdraw from the GoatVault.
    function _withdraw(uint256 _amount) internal override {
        uint256 shares = _convertToShares(_amount);
        uint256 sharesBalance = IERC20(goatVault).balanceOf(address(this));

        shares = Math.min(shares, sharesBalance);
        IGoatVault(goatVault).withdraw(shares);
    }

    /// @notice Sets the maximum allowance of the base asset for the GoatVault.
    /// 
    /// This function performs the following actions:
    /// - Grants the GoatVault an unlimited allowance to spend the base asset held by the contract.
    function _giveAllowances() internal override {
        IERC20(asset).forceApprove(goatVault, type(uint256).max);
    }

    /// @notice Revokes the allowance of the base asset for the GoatVault.
    /// 
    /// This function performs the following actions:
    /// - Sets the allowance of the base asset for the GoatVault to zero, effectively revoking any previous allowances.
    function _revokeAllowances() internal override {
        IERC20(asset).forceApprove(goatVault, 0);
    }
}