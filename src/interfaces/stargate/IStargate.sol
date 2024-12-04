// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.9.0;

interface IStargateV2Router {
    function token() external view returns (address);
    function lpToken() external view returns (address);
    function deposit(address receiver, uint256 amount) external payable returns (uint256);
    function redeem(uint256 amount, address receiver) external returns (uint256);
    function sharedDecimals() external view returns (uint8);
}

interface IStargateV2Chef {
    function deposit(address token, uint256 amount) external;
    function withdraw(address token, uint256 _amount) external;
    function emergencyWithdraw(address token) external;
    function balanceOf(address token, address user) external view returns (uint256);
    function claim(address[] calldata lpTokens) external;
}