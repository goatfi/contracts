// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";

interface ICurveLiquidityPool is IERC20 {
    function add_liquidity(uint256[] memory _amounts, uint256 _min_mint_amount) external returns (uint256);
    function remove_liquidity(uint256 _burn_amount, uint256[] memory _min_amounts) external returns (uint256);
    function remove_liquidity_one_coin(uint256 _burn_amount, int128 i, uint256 _min_received) external returns (uint256);
    function calc_withdraw_one_coin(uint256 _burn_amount, int128 i) external view returns (uint256);
    function calc_token_amount (uint256[] memory _amounts, bool _is_deposit) external view returns (uint256);
    function coins (uint256 _index) external view returns (address);
    function N_COINS() external view returns (uint256);
    function get_balances() external view returns (uint256[] memory);
    function stored_rates() external view returns (uint256[] memory);
}