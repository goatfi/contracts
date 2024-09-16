// SPDX-License-Identifier: GNU AGPLv3

pragma solidity 0.8.27;

import { IERC20, SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { IPool } from "@aave/core/contracts/interfaces/IPool.sol";
import { IAToken } from "@aave/core/contracts/interfaces/IAToken.sol";
import { StrategyAdapter } from "src/abstracts/StrategyAdapter.sol";
import { Errors } from "src/infra/libraries/Errors.sol";

contract AaveAdapter is StrategyAdapter {
    using SafeERC20 for IERC20;

    address public immutable aave;
    address public immutable aToken;

    /*//////////////////////////////////////////////////////////////////////////
                                     CONSTRUCTOR
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Constructor for the strategy adapter.
    /// @param _multistrategy The address of the multi-strategy contract.
    /// @param _asset The address of the asset.
    /// @param _aave The address of the Aave Pool.
    /// @param _aToken The address of the aToken related to asset.
    /// @param _name The name of this Strategy Adapter.
    /// @param _id The type identifier of this Strategy Adapter.
    constructor(
        address _multistrategy,
        address _asset,
        address _aave,
        address _aToken,
        string memory _name,
        string memory _id
    ) 
        StrategyAdapter(_multistrategy, _asset, _name, _id)
    {   
        require(_aave != address(0) && _aToken != address(0), Errors.ZeroAddress());
        
        aave = _aave;
        aToken = _aToken;
        _giveAllowances();
    }

    /*//////////////////////////////////////////////////////////////////////////
                            INTERNAL CONSTANT FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Calculates the total assets managed by the contract.
    /// 
    /// This function performs the following actions:
    /// - Retrieves the scaled balance of assets supplied to Aave.
    /// - Retrieves the base asset balance held by the contract.
    /// 
    /// @return The total amount of assets managed by the contract.
    function _totalAssets() internal override view returns(uint256) {
        uint256 assetsSupplied = IAToken(aToken).scaledBalanceOf(address(this));
        uint256 assetBalance = IERC20(asset).balanceOf(address(this));

        return assetsSupplied + assetBalance;
    }

    /*//////////////////////////////////////////////////////////////////////////
                            INTERNAL NON-CONSTANT FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Deposits into into Aave.
    /// 
    /// This function performs the following actions:
    /// - Retrieves the current balance of the base asset held by the contract.
    /// - Deposits the entire base asset balance into Aave.
    function _deposit() internal override {
        uint256 assetBalance = IERC20(asset).balanceOf(address(this));
        IPool(aave).deposit(asset, assetBalance, address(this), 0);
    }

    /// @notice Withdraws a specified amount of assets from Aave.
    /// @param _amount The amount of assets to withdraw from the Aave.
    function _withdraw(uint256 _amount) internal override {
        IPool(aave).withdraw(asset, _amount, address(this));
    }

    /// @notice Performs an emergency withdrawal of all assets from Aave.
    /// This function is intended for emergency situations where all assets need to be withdrawn immediately.
    function _emergencyWithdraw() internal override {
        uint256 assetsSupplied = IAToken(aToken).scaledBalanceOf(address(this));
        IPool(aave).withdraw(asset, assetsSupplied, address(this));
    }

    /// @notice Grants Aave an unlimited allowance to spend the base asset held by the contract.
    function _giveAllowances() internal override {
        IERC20(asset).forceApprove(aave, type(uint256).max);
    }

    /// @notice Sets the allowance of the base asset for Aave to zero, effectively revoking any previous allowances.
    function _revokeAllowances() internal override {
        IERC20(asset).forceApprove(aave, 0);
    }
}