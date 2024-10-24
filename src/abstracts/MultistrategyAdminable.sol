// SPDX-License-Identifier: GNU AGPLv3

pragma solidity 0.8.27;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";
import { IMultistrategyAdminable } from "interfaces/infra/multistrategy/IMultistrategyAdminable.sol";
import { Errors } from "src/infra/libraries/Errors.sol";

abstract contract MultistrategyAdminable is IMultistrategyAdminable, Ownable, Pausable {
    /*//////////////////////////////////////////////////////////////////////////
                                       STORAGE
    //////////////////////////////////////////////////////////////////////////*/

    /// @inheritdoc IMultistrategyAdminable
    address public manager;

    /// @inheritdoc IMultistrategyAdminable
    mapping(address guardianAddress => bool isActive) public guardians;

    /// @notice Sets the Owner and Manager addresses.
    /// @param _owner The address of the initial owner.
    /// @param _manager The address of the initial manager.
    constructor(address _owner, address _manager) Ownable(_owner) {
        manager = _manager;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    MODIFIERS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Reverts if called by any account other than the owner or the manager.
    modifier onlyManager() {
        require(
            msg.sender == owner() || 
            msg.sender == manager, 
            Errors.CallerNotManager(msg.sender)
        );
        _;
    }

    /// @notice Reverts if called by any account other than the owner, the manager, or a guardian.
    modifier onlyGuardian() {
        require(
            msg.sender == owner() || 
            msg.sender == manager || 
            guardians[msg.sender], 
            Errors.CallerNotGuardian(msg.sender)
        );
        _;
    }

    /*//////////////////////////////////////////////////////////////////////////
                               USER-FACING NON-CONSTANT FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @inheritdoc IMultistrategyAdminable
    function setManager(address _manager) external onlyOwner {
        require(_manager != address(0), Errors.ZeroAddress());

        manager = _manager;
        emit ManagerSet(_manager);
    }

    /// @inheritdoc IMultistrategyAdminable
    function enableGuardian(address _guardian) external onlyOwner {
        guardians[_guardian] = true;
        emit GuardianEnabled(_guardian);
    }

    /// @inheritdoc IMultistrategyAdminable
    function revokeGuardian(address _guardian) external onlyOwner {
        guardians[_guardian] = false;
        emit GuardianRevoked(_guardian);
    }

    /// @inheritdoc IMultistrategyAdminable
    function pause() external onlyGuardian {
        _pause();
    }

    /// @inheritdoc IMultistrategyAdminable
    function unpause() external onlyOwner {
        _unpause();
    }
}