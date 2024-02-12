// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { SafeERC20, IERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { IGoatRewardPool } from "interfaces/infra/IGoatRewardPool.sol";
import { IWrappedNative } from "interfaces/common/IWrappedNative.sol";

/// @notice All Goat protocol fees will flow through to the treasury and the reward pool
/// @dev Wrapped ETH will build up on this contract
contract GoatFeeBatch is Ownable {
    using SafeERC20 for IERC20;

    /// @notice Native token (WETH)
    IERC20 public immutable native;

    /// @notice Treasury address
    address public treasury;

    /// @notice Reward pool address
    address public rewardPool;

    /// @notice Vault harvester
    address public harvester;

    /// @notice Treasury fee of the total native received on the contract (1 = 0.1%)
    uint256 public treasuryFee;

    /// @notice Denominator constant
    uint256 constant public DIVISOR = 1000;

    /// @notice Max Treasury Fee. The Treasury will never get more than the stakers.
    uint256 constant public MAX_TREASURY_FEE = 499;

    /// @notice Duration of reward distributions
    uint256 public duration;

    /// @notice Minimum operating gas level on the harvester
    uint256 public harvesterMax;

    /// @notice Whether to send gas to the harvester
    bool public sendHarvesterGas;

    /// @notice Fees have been harvested
    /// @param totalHarvested Total fee amount that has been processed
    /// @param timestamp Timestamp of the harvest
    event Harvest(uint256 totalHarvested, uint256 timestamp);
    /// @notice Harvester has been sent gas
    /// @param gas Amount of gas that has been sent
    event SendHarvesterGas(uint256 gas);
    /// @notice Treasury fee that has been sent
    /// @param token Token that has been sent
    /// @param amount Amount of the token sent
    event DistributeTreasuryFee(address indexed token, uint256 amount);
    /// @notice Reward pool has been notified
    /// @param token Token used as a reward
    /// @param amount Amount of the token used
    /// @param duration Duration of the distribution
    event NotifyRewardPool(address indexed token, uint256 amount, uint256 duration);
    /// @notice Reward pool set
    /// @param rewardPool New reward pool address
    event SetRewardPool(address rewardPool);
    /// @notice Treasury set
    /// @param treasury New treasury address
    event SetTreasury(address treasury);
    /// @notice Whether to send gas to harvester has been set
    /// @param send Whether to send gas to harvester
    event SetSendHarvesterGas(bool send);
    /// @notice Harvester set
    /// @param harvester New harvester address
    /// @param harvesterMax Minimum operating gas level for the harvester
    event SetHarvester(address harvester, uint256 harvesterMax);
    /// @notice Treasury fee set
    /// @param fee New fee split for the treasury
    event SetTreasuryFee(uint256 fee);
    /// @notice Reward pool duration set
    /// @param duration New duration of the reward distribution
    event SetDuration(uint256 duration);
    /// @notice Rescue an unsupported token
    /// @param token Address of the token
    /// @param recipient Address to send the token to
    event RescueTokens(address token, address recipient);

    /// @notice The duration has to be greater than 1h
    error Duration(uint256 duration);
    /// @notice The owner cannot withdraw the staked token
    error WithdrawingRewardToken();
    /// @notice Failed To Send ether
    error FailedToSendEther();

    /// @notice Contract constructor
    /// @param _native WETH address
    /// @param _rewardPool Reward pool address
    /// @param _treasury Treasury address
    /// @param _treasuryFee Treasury fee split
    constructor(
        address _native,
        address _rewardPool,
        address _treasury,
        uint256 _treasuryFee 
    ) Ownable(msg.sender) {
        native = IERC20(_native);
        treasury = _treasury;
        rewardPool = _rewardPool;
        treasuryFee = _treasuryFee;
        native.forceApprove(rewardPool, type(uint).max);
        duration = 7 days;
    }

    /// @notice Distribute the fees to the harvester, treasury and reward pool
    function harvest() external {
        uint256 totalFees = native.balanceOf(address(this));

        if (sendHarvesterGas) _sendHarvesterGas();
        _distributeTreasuryFee();
        _notifyRewardPool();

        emit Harvest(totalFees - native.balanceOf(address(this)), block.timestamp);
    }

    /// @dev Unwrap the required amount of native and send to the harvester
    function _sendHarvesterGas() private {
        uint256 nativeBal = native.balanceOf(address(this));

        uint256 harvesterBal = harvester.balance + native.balanceOf(harvester);
        if (harvesterBal < harvesterMax) {
            uint256 gas = harvesterMax - harvesterBal;
            if (gas > nativeBal) {
                gas = nativeBal;
            }
            IWrappedNative(address(native)).withdraw(gas);
            (bool sent, ) = harvester.call{value: gas}("");
            if(!sent) revert FailedToSendEther();

            emit SendHarvesterGas(gas);
        }
    }

    /// @dev Swap to required treasury tokens and send the treasury fees onto the treasury
    function _distributeTreasuryFee() private {
        uint256 treasuryFeeAmount = native.balanceOf(address(this)) * treasuryFee / DIVISOR;

        native.safeTransfer(treasury, treasuryFeeAmount);
        emit DistributeTreasuryFee(address(native), treasuryFeeAmount);
    }

    /// @dev Swap to required reward tokens and notify the reward pool
    function _notifyRewardPool() private {
        uint256 rewardPoolAmount = native.balanceOf(address(this));

        IGoatRewardPool(rewardPool).notifyRewardAmount(address(native), rewardPoolAmount, duration);
        emit NotifyRewardPool(address(native), rewardPoolAmount, duration);
    }

    /* ----------------------------------- VARIABLE SETTERS ----------------------------------- */

    /// @notice Set the reward pool
    /// @param _rewardPool New reward pool address
    function setRewardPool(address _rewardPool) external onlyOwner {
        rewardPool = _rewardPool;
        native.forceApprove(rewardPool, type(uint).max);
        emit SetRewardPool(_rewardPool);
    }

    /// @notice Set the treasury
    /// @param _treasury New treasury address
    function setTreasury(address _treasury) external onlyOwner {
        treasury = _treasury;
        emit SetTreasury(_treasury);
    }

    /// @notice Set whether the harvester should be sent gas
    /// @param _sendGas Whether the harvester should be sent gas
    function setSendHarvesterGas(bool _sendGas) external onlyOwner {
        sendHarvesterGas = _sendGas;
        emit SetSendHarvesterGas(_sendGas);
    }

    /// @notice Set the harvester and the minimum operating gas level of the harvester
    /// @param _harvester New harvester address
    /// @param _harvesterMax New minimum operating gas level of the harvester
    function setHarvesterConfig(address _harvester, uint256 _harvesterMax) external onlyOwner {
        harvester = _harvester;
        harvesterMax = _harvesterMax;
        emit SetHarvester(_harvester, _harvesterMax);
    }

    /// @notice Set the treasury fee
    /// @param _treasuryFee New treasury fee split
    function setTreasuryFee(uint256 _treasuryFee) external onlyOwner {
        if (_treasuryFee > MAX_TREASURY_FEE) _treasuryFee = MAX_TREASURY_FEE;
        treasuryFee = _treasuryFee;
        emit SetTreasuryFee(_treasuryFee);
    }

    /// @notice Set the duration of the reward distribution
    /// @param _duration New duration of the reward distribution
    function setDuration(uint256 _duration) external onlyOwner {
        if(_duration < 1 hours || _duration > 365 days) revert Duration(_duration);
        duration = _duration;
        emit SetDuration(_duration);
    }

    /* ------------------------------------- SWEEP TOKENS ------------------------------------- */

    /// @notice Rescue an unsupported token
    /// @param _token Address of the token
    /// @param _recipient Address to send the token to
    function rescueTokens(address _token, address _recipient) external onlyOwner {
        if(_token == address(native)) revert WithdrawingRewardToken();

        uint256 amount = IERC20(_token).balanceOf(address(this));
        IERC20(_token).safeTransfer(_recipient, amount);
        emit RescueTokens(_token, _recipient);
    }

    /// @notice Support unwrapped native
    receive() external payable {}
}