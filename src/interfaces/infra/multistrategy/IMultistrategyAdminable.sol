// SPDX-License-Identifier: GNU AGPLv3

pragma solidity >=0.8.20 <= 0.9.0;

/// @title IMultistrategyAdminable
/// @notice Contract module that provides a 3 level access control mechanism, with an owner, a manager
/// and a list of guardians that can be granted exclusive access to specific functions.
/// The inheriting contract must set the initial owner and the initial manager in the constructor.
interface IMultistrategyAdminable {
    /*//////////////////////////////////////////////////////////////////////////
                                       EVENTS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Emitted when a new manager is set.
    /// @param manager The address of the new manager.
    event SetManager(address indexed manager);

    /// @notice Emitted when a new guardian has been granted access.
    /// @param guardian The address of the guardian.
    event EnableGuardian(address indexed guardian);

    /// @notice Emitted when a the access of a guardian has been revoked.
    /// @param guardian The address of the guardian.
    event RevokeGuardian(address indexed guardian);

    /*//////////////////////////////////////////////////////////////////////////
                                 CONSTANT FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice The address of the manager.
    function manager() external view returns (address);

    /// @notice List of addresses enabled as guardian.
    /// @param guardian The address to check if it is a guardian.
    function guardians(address guardian) external view returns (bool);
    
    /*//////////////////////////////////////////////////////////////////////////
                               NON-CONSTANT FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Sets the manager address.
    /// @dev Doesn't revert if:
    /// - manager address is zero address.
    /// - manager address is the same as previous manager address.
    /// @param manager Address of the new manager.
    function setManager(address manager) external;

    /// @notice Enables an address to be a guardian.
    /// @dev Doesn't revert if:
    /// - guardian address is zero address.
    /// - guardian address is already enabled as guardian.
    /// @param guardian The address of the guardian.
    function enableGuardian(address guardian) external;

    /// @notice Revokes an address to be a guardian.
    /// @dev Doesn't revert if:
    /// - guardian address is zero address.
    /// - guardian address is already revoked.
    /// @param guardian The address of the guardian.
    function revokeGuardian(address guardian) external;

    /// @notice Pauses the smart contract.
    /// @dev Functions that implement the `paused` modifier will revert when called.
    /// Guardians, Manager and Owner can call this function
    function pause() external;

    /// @notice Unpauses the smart contract.
    /// @dev Functions that implement the `paused` won't revert when called.
    /// Guardians, Manager and Owner can call this function
    function unpause() external;
}