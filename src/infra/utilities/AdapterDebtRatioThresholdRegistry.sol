// SPDX-License-Identifier: MIT

pragma solidity 0.8.27;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Errors } from "src/infra/libraries/Errors.sol";

contract AdapterDebtRatioThresholdRegistry is Ownable {
    /// @notice Stores debt ratio thresholds for the adapters.
    /// @dev If threshold == 0, it means it has no threshold.
    mapping(address => uint256) public threshold;

    /// @notice Emitted when a debt ratio is set or reset
    event ThresholdSet(address indexed adapter, uint256 debtRatio);

    constructor(address _initialOwner) Ownable(_initialOwner) {}

    /// @notice Sets the debt ratio for an address (max 10000)
    /// @param _adapter The adapter to set the threshold for.
    /// @param _debtRatioThreshold The threshold value.
    function setThreshold(address _adapter, uint256 _debtRatioThreshold) external onlyOwner {
        if (_debtRatioThreshold > 10_000) revert Errors.DebtRatioAboveMaximum(_debtRatioThreshold);
        threshold[_adapter] = _debtRatioThreshold;
        emit ThresholdSet(_adapter, _debtRatioThreshold);
    }

    /// @notice Resets the debt ratio for an adapter to 0
    /// @param _adapter The address to reset.
    function removeThreshold(address _adapter) external onlyOwner {
        threshold[_adapter] = 0;
        emit ThresholdSet(_adapter, 0);
    }
}