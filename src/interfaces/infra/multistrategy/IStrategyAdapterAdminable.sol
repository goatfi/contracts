// SPDX-License-Identifier: GNU AGPLv3

pragma solidity >=0.8.20 <= 0.9.0;

interface IStrategyAdapterAdminable {
    /// @notice Emitted when a new guardian has been granted access.
    /// @param guardian The address of the guardian.
    event GuardianEnabled(address indexed guardian);

    /// @notice Emitted when a the access of a guardian has been revoked.
    /// @param guardian The address of the guardian.
    event GuardianRevoked(address indexed guardian);

    /// @notice List of addresses enabled as guardian.
    /// @param guardian The address to check if it is a guardian.
    function guardians(address guardian) external view returns (bool);

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
}