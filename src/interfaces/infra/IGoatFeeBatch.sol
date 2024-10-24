// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IGoatFeeBatch {
    function harvest() external;
    function setRewardPool(address _rewardPool) external;
    function setTreasury(address _treasury) external;
    function setSendHarvesterGas(bool _sendGas) external;
    function setHarvesterConfig(address _harvester, uint256 _harvesterMax) external;
    function setTreasuryFee(uint256 _treasuryFee) external;
    function setDuration(uint256 _duration) external;
    function rescueTokens(address _token, address _recipient) external;
    function transferOwnership(address owner) external;
}