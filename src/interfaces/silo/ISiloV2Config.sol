// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

struct ConfigData {
    uint256 daoFee;
    uint256 deployerFee;
    address silo;
    address token;
    address protectedShareToken;
    address collateralShareToken;
    address debtShareToken;
    address solvencyOracle;
    address maxLtvOracle;
    address interestRateModel;
    uint256 maxLtv;
    uint256 lt;
    uint256 liquidationTargetLtv;
    uint256 liquidationFee;
    uint256 flashloanFee;
    address hookReceiver;
    bool callBeforeQuote;
}

interface ISiloV2Config {
    function getConfig(address _silo) external view returns (ConfigData memory config);
}