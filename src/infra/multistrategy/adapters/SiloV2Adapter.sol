// SPDX-License-Identifier: GNU AGPLv3
pragma solidity 0.8.27;

import { ERC4626AdapterHarvestable } from "src/abstracts/ERC4626AdapterHarvestable.sol";
import { ISiloIncentivesController } from "interfaces/silo/ISilo.sol";

contract SiloV2Adapter is ERC4626AdapterHarvestable {

    /// @notice The Silo incentives controller.
    ISiloIncentivesController public incentivesController;

    /*//////////////////////////////////////////////////////////////////////////
                                     CONSTRUCTOR
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Constructor for the strategy adapter.
    /// @param _multistrategy The address of the multi-strategy contract.
    /// @param _asset The address of the asset.
    /// @param _vault The address of the ERC4626 vault.
    /// @param _name The name of this Strategy Adapter.
    /// @param _id The type identifier of this Strategy Adapter.
    constructor(
        address _multistrategy,
        address _asset,
        address _vault,
        address _incentivesController,
        HarvestAddresses memory _harvestAddresses,
        string memory _name,
        string memory _id
    )
        ERC4626AdapterHarvestable(
            _multistrategy,
            _asset,
            _vault,
            _harvestAddresses,
            _name,
            _id
        )
    {
        incentivesController = ISiloIncentivesController(_incentivesController);
    }

    /*//////////////////////////////////////////////////////////////////////////
                            INTERNAL NON-CONSTANT FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Claims the rewards.
    function _claim() internal override {
        incentivesController.claimRewards(address(this));
    }
}