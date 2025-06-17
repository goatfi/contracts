// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";

contract MockCurveGauge {
    mapping(address => uint256) private _balances;
    address public lp_token;

    constructor(address _lpToken) {
        lp_token = _lpToken;
    }

    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }

    function deposit(uint256 _value) external {
        IERC20(lp_token).transferFrom(msg.sender, address(this), _value);
        _balances[msg.sender] += _value;
    }

    function deposit(uint256 _value, address _account) external {
        IERC20(lp_token).transferFrom(msg.sender, address(this), _value);
        _balances[_account] += _value;
    }

    function withdraw(uint256 _value) external {
        IERC20(lp_token).transfer(msg.sender, _value);
        _balances[msg.sender] -= _value;
    }
}