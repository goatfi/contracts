// SPDX-License-Identifier: GNU AGPLv3
pragma solidity 0.8.27;

interface ICurveGaugeFactory {
    function mint(address _gauge) external;
}