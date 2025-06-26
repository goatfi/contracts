// SPDX-License-Identifier: GNU AGPLv3
pragma solidity 0.8.27;

import { ERC4626AdapterHarvestable } from "src/abstracts/ERC4626AdapterHarvestable.sol";
import { AssetsSonic } from "@addressbook/AddressBook.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { ISiloV2Vault } from "interfaces/silo/ISiloV2Vault.sol";
import { ISiloV2Market } from "interfaces/silo/ISiloV2Market.sol";
import { ISiloV2Config, ConfigData } from "interfaces/silo/ISiloV2Config.sol";
import { ISiloV2IncentivesController } from "interfaces/silo/ISiloV2IncentivesController.sol";
import { ISiloHookReceiver } from "interfaces/silo/ISiloHookReceiver.sol";
import { IxSilo } from "interfaces/silo/ISilo.sol";

contract SiloV2VaultAdapter is ERC4626AdapterHarvestable {
    /// @notice The Silo incentives controller of the Silo Vault.
    ISiloV2IncentivesController public vaultIncentivesController;

    /*//////////////////////////////////////////////////////////////////////////
                                     CONSTRUCTOR
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Constructor for the strategy adapter.
    /// @param _multistrategy The address of the multi-strategy contract.
    /// @param _asset The address of the asset.
    /// @param _vault The address of the ERC4626 vault.
    /// @param _vaultIncentivesController The address of the Silo Vault Incentives Controller
    /// @param _name The name of this Strategy Adapter.
    /// @param _id The type identifier of this Strategy Adapter.
    constructor(
        address _multistrategy,
        address _asset,
        address _vault,
        address _vaultIncentivesController,
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
        vaultIncentivesController = ISiloV2IncentivesController(_vaultIncentivesController);
    }

    /*//////////////////////////////////////////////////////////////////////////
                            INTERNAL NON-CONSTANT FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Claims the rewards from the incentives controller.
    function _claim() internal override {
        if(address(vaultIncentivesController) != address(0)) {
            vaultIncentivesController.claimRewards(address(this));
        }

        uint256 amountOfMarkets = ISiloV2Vault(address(vault)).withdrawQueueLength();
        for(uint256 i = 0; i < amountOfMarkets; ++i) {
            address market = ISiloV2Vault(address(vault)).withdrawQueue(i);
            address config = ISiloV2Market(market).config();
            ConfigData memory configData = ISiloV2Config(config).getConfig(market);
            ISiloV2IncentivesController gauge = ISiloV2IncentivesController(ISiloHookReceiver(configData.hookReceiver).configuredGauges(market));
            string[] memory programNames = gauge.getAllProgramsNames();
            uint256 unclaimedRewards;
            for(uint256 j = 0; j < programNames.length; ++j) {
                unclaimedRewards += gauge.getRewardsBalance(address(this), programNames[i]);
            }
            if(unclaimedRewards > 0) gauge.claimRewards(address(this));
        }

        uint256 xSiloBalance = IERC20(AssetsSonic.xSILO).balanceOf(address(this));
        if(xSiloBalance > 0) {
            IxSilo(AssetsSonic.xSILO).redeemSilo(xSiloBalance, 0);
        }
    }

    /*//////////////////////////////////////////////////////////////////////////
                            EXTERNAL NON-CONSTANT FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Sets a new incentives controller contract.
    /// @dev Only callable by the contract owner.
    /// @param _vaultIncentivesController The address of the new incentives controller.
    function setVaultIncentivesController(address _vaultIncentivesController) external onlyOwner {
        vaultIncentivesController = ISiloV2IncentivesController(_vaultIncentivesController);
    }
}