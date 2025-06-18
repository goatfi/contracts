// SPDX-License-Identifier: GNU AGPLv3

pragma solidity 0.8.27;

import { IERC20, SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { StrategyAdapterHarvestable } from "src/abstracts/StrategyAdapterHarvestable.sol";
import { IStargateV2Chef, IStargateV2Router } from "interfaces/stargate/IStargate.sol";
import { Errors } from "src/infra/libraries/Errors.sol";

contract StargateAdapter is StrategyAdapterHarvestable {
    using SafeERC20 for IERC20;
    using Math for uint256;

    struct StargateAddresses {
        address router;
        address chef;
    }

    /// @notice The Stargate Router contract.
    IStargateV2Router public stargateRouter;

    /// @notice The Stargate Chef contract.
    IStargateV2Chef public stargateChef;

    /// @notice The address of the Stargate LP Token contract.
    address public stargateLPToken;

    /// @notice An array of LP token addresses to claim rewards for.
    address[] lpTokensToClaimFor;

    /*//////////////////////////////////////////////////////////////////////////
                                     CONSTRUCTOR
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Constructor for the strategy adapter.
    /// @param _multistrategy The address of the multi-strategy contract.
    /// @param _asset The address of the asset.
    /// @param _harvestAddresses Struct of Protocol Addresses.
    /// @param _stargateAddresses Struct of Stargate Addresses.
    /// @param _name The name of this Strategy Adapter.
    /// @param _id The type identifier of this Strategy Adapter.
    constructor(
        address _multistrategy,
        address _asset,
        HarvestAddresses memory _harvestAddresses,
        StargateAddresses memory _stargateAddresses,
        string memory _name,
        string memory _id
    ) 
        StrategyAdapterHarvestable(_multistrategy, _asset, _harvestAddresses,_name, _id)
    {   
        stargateRouter = IStargateV2Router(_stargateAddresses.router);
        stargateChef = IStargateV2Chef(_stargateAddresses.chef);
        stargateLPToken = stargateRouter.lpToken();
        lpTokensToClaimFor.push(stargateLPToken);
        _giveAllowances();
    }

    /*//////////////////////////////////////////////////////////////////////////
                            INTERNAL CONSTANT FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Returns the total amount of assets held in this adapter.
    function _totalAssets() internal override view returns(uint256) {
        uint256 assetsSupplied = stargateChef.balanceOf(stargateLPToken, address(this));
        return assetsSupplied + _balance();
    }

    /// @inheritdoc StrategyAdapterHarvestable
    function _verifyRewardToken(address _token) internal view override {
        require(_token != address(stargateRouter) && _token != address(stargateChef), Errors.InvalidRewardToken(_token));
    }

    /*//////////////////////////////////////////////////////////////////////////
                            INTERNAL NON-CONSTANT FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Deposits all the balance into Stargate.
    function _deposit() internal override {
        stargateRouter.deposit(address(this), _balance());
        uint256 balanceOfLP = IERC20(stargateLPToken).balanceOf(address(this));
        stargateChef.deposit(stargateLPToken, balanceOfLP);
    }

    /// @notice Withdraws a specified amount of assets from Stargate.
    /// @param _amount The amount of assets to withdraw from the Silo.
    function _withdraw(uint256 _amount) internal override {
        stargateChef.withdraw(stargateLPToken, _amount);
        stargateRouter.redeem(_amount, address(this));
    }

    /// @notice Performs an emergency withdrawal of all assets from Stargate.
    /// This function is intended for emergency situations where all assets need to be withdrawn immediately.
    function _emergencyWithdraw() internal override {
        uint256 assetsSupplied = stargateChef.balanceOf(stargateLPToken, address(this));
        if (assetsSupplied > 0) {
            stargateChef.withdraw(stargateLPToken, assetsSupplied);
            stargateRouter.redeem(assetsSupplied, address(this));
        }
    }

    /// @notice Sets the maximum allowance of the base asset for Stargate.
    function _giveAllowances() internal override {
        IERC20(asset).forceApprove(address(stargateRouter), type(uint).max);
        IERC20(stargateLPToken).forceApprove(address(stargateChef), type(uint).max);
        IERC20(wrappedGas).forceApprove(swapper, type(uint).max);
    }

    /// @notice Revokes the allowance of the base asset for Stargate.
    function _revokeAllowances() internal override {
        IERC20(asset).forceApprove(address(stargateRouter), 0);
        IERC20(stargateLPToken).forceApprove(address(stargateChef), 0);
        IERC20(wrappedGas).forceApprove(swapper, 0);
    }

    /// @inheritdoc StrategyAdapterHarvestable
    function _claim() internal override {
        stargateChef.claim(lpTokensToClaimFor);
    }
}