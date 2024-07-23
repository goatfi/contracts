// SPDX-License-Identifier: GNU AGPLv3

pragma solidity >=0.8.20 <= 0.9.0;

interface IStrategyAdapterAdminable {
    /// @notice Emitted when a new guardian has been granted access.
    /// @param _guardian The address of the guardian.
    event GuardianEnabled(address indexed _guardian);

    /// @notice Emitted when a the access of a guardian has been revoked.
    /// @param _guardian The address of the guardian.
    event GuardianRevoked(address indexed _guardian);

    /// @notice List of addresses enabled as guardian.
    /// @param _guardian The address to check if it is a guardian.
    function guardians(address _guardian) external view returns (bool);

    /// @notice Enables an address to be a guardian.
    /// @dev Doesn't revert if:
    /// - guardian address is zero address.
    /// - guardian address is already enabled as guardian.
    /// @param _guardian The address of the guardian.
    function enableGuardian(address _guardian) external;

    /// @notice Revokes an address to be a guardian.
    /// @dev Doesn't revert if:
    /// - guardian address is zero address.
    /// - guardian address is already revoked.
    /// @param _guardian The address of the guardian.
    function revokeGuardian(address _guardian) external;
}