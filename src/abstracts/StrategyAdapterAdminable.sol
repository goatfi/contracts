// SPDX-License-Identifier: GNU AGPLv3

pragma solidity 0.8.27;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";
import { IStrategyAdapterAdminable } from "interfaces/infra/multistrategy/IStrategyAdapterAdminable.sol";
import { Errors } from "src/infra/libraries/Errors.sol";

contract StrategyAdapterAdminable is IStrategyAdapterAdminable, Ownable, Pausable {
    /*//////////////////////////////////////////////////////////////////////////
                                       STORAGE
    //////////////////////////////////////////////////////////////////////////*/

    /// @inheritdoc IStrategyAdapterAdminable
    mapping(address guardianAddress => bool isActive) public guardians;

    constructor(address _owner) Ownable(_owner) {}

    /*//////////////////////////////////////////////////////////////////////////
                                    MODIFIERS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Reverts if called by any account other than the owner, the manager, or a guardian.
    modifier onlyGuardian() {
        require(msg.sender == owner() || guardians[msg.sender], Errors.CallerNotGuardian(msg.sender));
        _;
    }

    /*//////////////////////////////////////////////////////////////////////////
                               USER-FACING NON-CONSTANT FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @inheritdoc IStrategyAdapterAdminable
    function enableGuardian(address _guardian) external onlyOwner {
        guardians[_guardian] = true;
        emit GuardianEnabled(_guardian);
    }

    /// @inheritdoc IStrategyAdapterAdminable
    function revokeGuardian(address _guardian) external onlyOwner {
        guardians[_guardian] = false;
        emit GuardianRevoked(_guardian);
    }
}