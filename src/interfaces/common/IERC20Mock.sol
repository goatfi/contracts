// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20Mock {
    function mint(address account, uint256 amount) external;
    function burn(address account, uint256 amount) external;
} 