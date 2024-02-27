// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract FeeConfigurator is OwnableUpgradeable {

    struct FeeCategory {
        uint256 total;      // total fee charged on each harvest
        uint256 protocol;      // split of total fee going to the fee batcher
        uint256 call;       // split of total fee going to harvest caller
        uint256 strategist;     // split of total fee going to developer of the strategy
        string label;       // description of the type of fee category
        bool active;        // on/off switch for fee category
    }

    address public keeper;
    uint256 public totalLimit;
    uint256 constant DIVISOR = 1 ether;

    mapping(address => uint256) public stratFeeId;
    mapping(uint256 => FeeCategory) internal feeCategory;

    event SetStratFeeId(address indexed strategy, uint256 indexed id);
    event SetFeeCategory(
        uint256 indexed id,
        uint256 total,
        uint256 protocol,
        uint256 call,
        uint256 strategist,
        string label,
        bool active
    );
    event Pause(uint256 indexed id);
    event Unpause(uint256 indexed id);
    event SetKeeper(address indexed keeper);

    /// @notice Initialize the contract
    /// @param _keeper Keeper address
    /// @param _totalLimit Max fees. 0.05 ether == 5%
    function initialize(
        address _keeper,
        uint256 _totalLimit
    ) public initializer {
        __Ownable_init(msg.sender);

        keeper = _keeper;
        totalLimit = _totalLimit;
    }

    /// @notice Checks that caller is either owner or keeper
    modifier onlyManager() {
        require(msg.sender == owner() || msg.sender == keeper, "!manager");
        _;
    }

    /// @notice Fetch fees for a strategy
    /// @param _strategy strategy to check
    function getFees(address _strategy) external view returns (FeeCategory memory) {
        return getFeeCategory(stratFeeId[_strategy], false);
    }

    /// @notice Fetch fees for a strategy
    /// @param _strategy strategy to check
    /// @param _adjust option to view fees as % of total harvest instead of % of total fee
    function getFees(address _strategy, bool _adjust) external view returns (FeeCategory memory) {
        return getFeeCategory(stratFeeId[_strategy], _adjust);
    }

    /// @notice fetch fee category for an id if active
    /// @param _id Id to fetch
    /// @param _adjust option to view fees as % of total harvest instead of % of total fee
    function getFeeCategory(uint256 _id, bool _adjust) public view returns (FeeCategory memory fees) {
        uint256 id = feeCategory[_id].active ? _id : 0;
        fees = feeCategory[id];
        if (_adjust) {
            uint256 _totalFee = fees.total;
            fees.protocol = fees.protocol * _totalFee / DIVISOR;
            fees.call = fees.call * _totalFee / DIVISOR;
            fees.strategist = fees.strategist * _totalFee / DIVISOR;
        }
    }

    /// @notice set a fee category id for a strategy that calls this function directly
    /// @param _feeId id to set for the strategy
    function setStratFeeId(uint256 _feeId) external {
        _setStratFeeId(msg.sender, _feeId);
    }

    /// @notice set a fee category id for a strategy that calls this function directly
    /// @param _strategy the strategy to set the feeId for
    /// @param _feeId id to set for the strategy
    function setStratFeeId(address _strategy, uint256 _feeId) external onlyManager {
        _setStratFeeId(_strategy, _feeId);
    }

    /// @notice set fee category ids for multiple strategies at once by a manager
    /// @param _strategies Strategies to set the ids for
    /// @param _feeIds The ids
    function setStratFeeId(address[] memory _strategies, uint256[] memory _feeIds) external onlyManager {
        uint256 stratLength = _strategies.length;
        for (uint256 i = 0; i < stratLength; i++) {
            _setStratFeeId(_strategies[i], _feeIds[i]);
        }
    }

    /// @notice internally set a fee category id for a strategy
    /// @param _strategy the strategy to set the feeId for
    /// @param _feeId id to set for the strategy
    function _setStratFeeId(address _strategy, uint256 _feeId) internal {
        stratFeeId[_strategy] = _feeId;
        emit SetStratFeeId(_strategy, _feeId);
    }

    /// @notice set values for a fee category using the relative split for call and strategist
    /// @param _id Id of the category to set the values for
    /// @param _total Total Fee.
    /// @param _call Harvester fee, 0.01 ether == 1% of total fee.
    /// @param _strategist Strategist Fee
    /// @param _label description of the type of fee category
    /// @param _active on/off switch for fee category
    /// @param _adjust == true: input call and strat fee as % of total harvest
    function setFeeCategory(
        uint256 _id,
        uint256 _total,
        uint256 _call,
        uint256 _strategist,
        string memory _label,
        bool _active,
        bool _adjust
    ) external onlyOwner {
        require(_total <= totalLimit, ">totalLimit");
        if (_adjust) {
            _call = _call * DIVISOR / _total;
            _strategist = _strategist * DIVISOR / _total;
        }
        uint256 protocol = DIVISOR - _call - _strategist;

        FeeCategory memory category = FeeCategory(_total, protocol, _call, _strategist, _label, _active);
        feeCategory[_id] = category;
        emit SetFeeCategory(_id, _total, protocol, _call, _strategist, _label, _active);
    }

    /// @notice deactivate a fee category making all strategies with this fee id revert to default fees
    /// @param _id Id of the category to pause
    function pause(uint256 _id) external onlyManager {
        feeCategory[_id].active = false;
        emit Pause(_id);
    }

    /// @notice Reactivate a category
    /// @param _id Id of the category to unpause
    function unpause(uint256 _id) external onlyManager {
        feeCategory[_id].active = true;
        emit Unpause(_id);
    }

    /// @notice Change the keeper
    /// @param _keeper new keeper
    function setKeeper(address _keeper) external onlyManager {
        keeper = _keeper;
        emit SetKeeper(_keeper);
    }
}