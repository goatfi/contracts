// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

interface ICurveVaultXChain {
	function deposit(address _staker, uint256 _amount) external;

	function withdraw(uint256 _shares) external;

    function withdrawAll() external;

    function sdGauge() external returns (address);
}