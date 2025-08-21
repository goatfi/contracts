// SPDX-License-Identifier: GNU AGPLv3
pragma solidity 0.8.27;

interface ICurveGaugeFactory {
    function mint(address _gauge) external;
    function is_valid_gauge(address _gauge) external view returns (bool);
    function get_gauge_from_lp_token(address _lpToken) external view returns (address);
}