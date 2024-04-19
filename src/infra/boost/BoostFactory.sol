// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import { IGoatBoost } from "interfaces/infra/IGoatBoost.sol";
import { IGoatVaultFactory } from "interfaces/infra/IGoatVaultFactory.sol";

/// @title A factory for creating and deploying Boost contracts
contract BoostFactory {
    /// @notice Address of the factory contract
    address public factory;
    /// @notice Address of the Boost implementation contract
    address public boostImpl;
    /// @notice Address of the deployer who deployed the factory
    address public deployer;

    /// @notice Event emitted when a Boost is deployed
    /// @param boost Address of the deployed Boost contract
    event BoostDeployed(address indexed boost);

    /// @dev Sets the initial factory and Boost implementation addresses
    /// @param _factory Address of the factory contract
    /// @param _boostImpl Address of the Boost implementation contract
    constructor(address _factory, address _boostImpl) {
        factory = _factory;
        boostImpl = _boostImpl;
        deployer = msg.sender;
    }

    /// @notice Deploys a new Boost contract using the Boost implementation
    /// @param _vault Address of the staked token for the Boost
    /// @param _rewardToken Address of the reward token for the Boost
    /// @param _duration Duration of the Boost in seconds
    /// @param _manager Address of the boost manager
    /// @param _treasury Address of the treasury
    /// @dev Clones the Boost implementation, initializes it, sets treasury fee to 0, and transfers ownership to the deployer
    function deployBoost(address _vault, address _rewardToken, uint _duration, address _manager, address _treasury) external returns (address) {
        IGoatBoost boost = IGoatBoost(IGoatVaultFactory(factory).cloneContract(boostImpl));
        boost.initialize(_vault, _rewardToken, _duration, _manager, _treasury);
        boost.setTreasuryFee(0);
        boost.transferOwnership(deployer);
        emit BoostDeployed(address(boost));
        return address(boost);
    }
}