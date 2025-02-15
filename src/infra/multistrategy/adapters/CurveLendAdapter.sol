// SPDX-License-Identifier: GNU AGPLv3

pragma solidity 0.8.27;

import { IERC20, SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC4626 } from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { StrategyAdapter } from "src/abstracts/StrategyAdapter.sol";
import { Errors } from "src/infra/libraries/Errors.sol";

contract CurveLendAdapter is StrategyAdapter {
    using SafeERC20 for IERC20;
    using Math for uint256;

    /// @notice Address of the Lend Vault where crvUSD will be deposited as supply-side liquidity.
    address public immutable curveLendVault;
    /// @notice Address of the Goat Vault where funds will be send to auto-compound extra incentive rewards.
    address public immutable goatVault;
    /// @notice Thrown when Curve Lend Vault and Goat Vault deposit token addresses doesn't match.
    error WantMismatch();

    /*//////////////////////////////////////////////////////////////////////////
                                     CONSTRUCTOR
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Constructor for the strategy adapter.
    /// @param _multistrategy The address of the multi-strategy contract.
    /// @param _asset The address of the asset.
    /// @param _name The name of this Strategy Adapter.
    /// @param _id The type identifier of this Strategy Adapter.
    constructor(
        address _multistrategy,
        address _asset,
        string memory _name,
        string memory _id
    ) 
        StrategyAdapter(_multistrategy, _asset, _name, _id)
    {   

        _giveAllowances();
    }

    /*//////////////////////////////////////////////////////////////////////////
                            INTERNAL CONSTANT FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Calculates the total assets managed by the contract.
    /// 
    /// This function performs the following actions:
    /// - Retrieves the GoatVault's price per share.
    /// - Calculates the number of Curve Lend Vault shares based on the GoatVault's share balance and price per share.
    /// - Converts the Curve Lend Vault shares to the equivalent amount of assets.
    /// - Adds the base asset balance held by the contract.
    /// 
    /// @return The total amount of assets managed by the contract, including both assets supplied to Curve Lend and the base asset balance.
    function _totalAssets() internal override view returns(uint256) {

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

    }

    /*//////////////////////////////////////////////////////////////////////////
                            INTERNAL NON-CONSTANT FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Deposits into into Curve Lend.
    /// 
    /// This function performs the following actions:
    /// - Deposits the entire base asset balance into Curve Lend.
    /// - Deposits the Curve Lend Vault shares into a Goat Vault.
    function _deposit() internal override {

    }

    
    /// @notice Withdraws a specified amount of assets from Curve Lend.
    /// 
    /// This function performs the following actions:
    /// - Calculates the number of Curve Lend Vault shares needed to withdraw the specified amount of assets.
    /// - Converts the required Curve Lend Vault shares to Goat Vault shares.
    /// - Withdraws the minimum of the required Goat Vault shares or the available Goat Vault shares.
    /// - Redeems the corresponding Curve Lend Vault shares to retrieve the assets.
    /// 
    /// @param _amount The amount of assets to withdraw from Curve Lend.
    function _withdraw(uint256 _amount) internal override {

    }

    /// @notice Performs an emergency withdrawal of all assets from Curve Lend.
    /// 
    /// This function performs the following actions:
    /// - Withdraws all Goat Vault shares.
    /// - Redeems all Curve Lend Vault shares to retrieve the assets.
    /// 
    /// This function is intended for emergency situations where all assets need to be withdrawn immediately.
    function _emergencyWithdraw() internal override {

    }

    /// @notice Grants the Curve Lend Vault an unlimited allowance to deposit `asset`.
    /// Also grants the Goat Vault an unlimited allowance to deposit Curve Lend Vault shares.
    function _giveAllowances() internal override {
        IERC20(asset).forceApprove(curveLendVault, type(uint256).max);
        IERC20(curveLendVault).forceApprove(goatVault, type(uint256).max);
    }

    /// @notice Sets the allowance of asset and Curve Lend Vault shares to zero, effectively revoking any previous allowances.
    function _revokeAllowances() internal override {
        IERC20(asset).forceApprove(curveLendVault, 0);
        IERC20(curveLendVault).forceApprove(goatVault, 0);
    }
}