// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../utils/BytesLib.sol";

contract GoatSwapper {
    using SafeERC20 for IERC20;
    using BytesLib for bytes;

    struct SwapInfo {
        address router;
        bytes data;
        uint256 amountIndex;
    }

    mapping(address => mapping(address => SwapInfo)) public swapInfo;

    address public native;
    address public keeper;
    address public deployer;

    constructor(address _native, address _keeper) {
        native = _native;
        keeper = _keeper;
        deployer = msg.sender;
    }

    modifier onlyManager() {
        require(msg.sender == deployer || msg.sender == keeper, "!manager");
        _;
    }

    /// @notice There is no swap data from  _fromToekn to _toToken
    /// @param fromToken Swap from Token
    /// @param toToken Swap to Token
    error NoSwapData(address fromToken, address toToken);

    /// @notice A swap with a route, failed
    /// @param router Router that threw the error
    /// @param data Swap data
    error SwapFailed(address router, bytes data);

    /// @notice Event called for a successful swap
    /// @param caller Who called the swap transaction
    /// @param fromToken Swap from Token
    /// @param toToken Swap to Token
    /// @param amountIn from Amount
    /// @param amountOut to Amount
    event Swap(address indexed caller, address indexed fromToken, address indexed toToken, uint256 amountIn, uint256 amountOut);

    /// @notice Event called when swap info has been set
    /// @param fromToken Swap from Token
    /// @param toToken Swap to Token
    /// @param swapInfo Swap info provided
    event SetSwapInfo(address indexed fromToken, address indexed toToken, SwapInfo swapInfo);


    /// @notice Swap from _fromToken to _toToken
    /// @param _fromToken Swap from Token
    /// @param _toToken Swap to Token
    /// @param _amountIn Amount of from to swap
    function swap(address _fromToken, address _toToken, uint256 _amountIn) external returns (uint256 amountOut) {
        IERC20(_fromToken).safeTransferFrom(msg.sender, address(this), _amountIn);
        _executeSwap(_fromToken, _toToken, _amountIn);
        amountOut = IERC20(_toToken).balanceOf(address(this));
        IERC20(_toToken).safeTransfer(msg.sender, amountOut);
        emit Swap(msg.sender, _fromToken, _toToken, _amountIn, amountOut);
    }

    function _executeSwap(address _fromToken, address _toToken, uint256 _amountIn) private {
        SwapInfo memory swapData = swapInfo[_fromToken][_toToken];
        address router = swapData.router;
        if (router == address(0)) revert NoSwapData(_fromToken, _toToken);
        bytes memory data = swapData.data;

        data = _insertData(data, swapData.amountIndex, abi.encode(_amountIn));

        _approveTokenIfNeeded(_fromToken, router);
        (bool success,) = router.call(data);
        if (!success) revert SwapFailed(router, data);
    }

    function _insertData(bytes memory _data, uint256 _index, bytes memory _newData) private pure returns (bytes memory data) {
        data = bytes.concat(
            bytes.concat(
                _data.slice(0, _index),
                _newData
            ),
            _data.slice(_index + 32, _data.length - (_index + 32))
        );
    }

    /// @notice Set swap info
    /// @param _fromToken Swap from Token
    /// @param _toToken Swap to Token
    /// @param _swapInfo Swap info provided
    function setSwapInfo(address _fromToken, address _toToken, SwapInfo calldata _swapInfo) external onlyManager {
        swapInfo[_fromToken][_toToken] = _swapInfo;
        emit SetSwapInfo(_fromToken, _toToken, _swapInfo);
    }

    /// @notice Set swap info
    /// @param _fromTokens Swap from Token address array
    /// @param _toTokens Swap to Token adddress array
    /// @param _swapInfos Swap infos 
    function setSwapInfos(address[] calldata _fromTokens, address[] calldata _toTokens, SwapInfo[] calldata _swapInfos) external onlyManager {
        uint256 tokenLength = _fromTokens.length;
        for (uint i; i < tokenLength;) {
            swapInfo[_fromTokens[i]][_toTokens[i]] = _swapInfos[i];
            emit SetSwapInfo(_fromTokens[i], _toTokens[i], _swapInfos[i]);
            unchecked {++i;}
        }
    }

    function _approveTokenIfNeeded(address token, address spender) private {
        if (IERC20(token).allowance(address(this), spender) == 0) {
            IERC20(token).safeIncreaseAllowance(spender, type(uint256).max);
        }
    }

    /// @notice Return the data to swap from native to _token
    /// @param _token Token to swap to
    /// @return router Router used
    /// @return data Swap data
    /// @return amountIndex Bytes index where the swap amount will be inserted
    function fromNative(address _token) external view returns (address router, bytes memory data, uint256 amountIndex) {
        router = swapInfo[native][_token].router;
        data = swapInfo[native][_token].data;
        amountIndex = swapInfo[native][_token].amountIndex;
    }

    /// @notice Return the data to swap from _token to native
    /// @param _token Token to swap to
    /// @return router Router used
    /// @return data Swap data
    /// @return amountIndex Bytes index where the swap amount will be inserted
    function toNative(address _token) external view returns (address router, bytes memory data, uint256 amountIndex) {
        router = swapInfo[_token][native].router;
        data = swapInfo[_token][native].data;
        amountIndex = swapInfo[_token][native].amountIndex;
    }

    /// @notice Set a new keeper address
    /// @param _keeper Keeper address
    function setKeeper(address _keeper) external onlyManager {
        keeper = _keeper;
    }

    /// @notice Renouce the ownership of the deployer so only the manager has permissions
    function renounceDeployer() public onlyManager {
        deployer = address(0);
    }
}