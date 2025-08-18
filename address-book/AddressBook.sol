// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {ProtocolArbitrum} from './arbitrum/Protocol.sol';
import {ProtocolBase} from './base/Protocol.sol';
import {ProtocolSonic} from './sonic/Protocol.sol';
import {AssetsArbitrum} from './arbitrum/Assets.sol';
import {AssetsBase} from './base/Assets.sol';
import {AssetsSonic} from './sonic/Assets.sol';
import {VaultsArbitrum} from './arbitrum/Vaults.sol';
import {VaultsSonic} from './sonic/Vaults.sol';
import {UtilitiesArbitrum} from './arbitrum/Utilities.sol';

contract Addressbook {
    error AddressNotFound(uint256 _chainId);

    function getTreasury(uint256 _chainId) external pure returns (address) {
        if(_chainId == 42161) return ProtocolArbitrum.TREASURY;
        if(_chainId == 8453) return ProtocolBase.TREASURY;
        if(_chainId == 146) return ProtocolSonic.TREASURY;

        revert AddressNotFound(_chainId);
    }

    function getManager(uint256 _chainId) external pure returns (address) {
        if(_chainId == 42161) return ProtocolArbitrum.MULTI_MANAGER;
        if(_chainId == 146) return ProtocolSonic.MULTI_MANAGER;
        
        revert AddressNotFound(_chainId);
    }

    function getGuardian(uint256 _chainId) external pure returns (address) {
        if(_chainId == 42161) return ProtocolArbitrum.GUARDIAN;
        if(_chainId == 146) return ProtocolSonic.GUARDIAN;

        revert AddressNotFound(_chainId);
    }

    function getTimelock(uint256 _chainId) external pure returns (address) {
        if(_chainId == 42161) return ProtocolArbitrum.TIMELOCK;
        if(_chainId == 8453) return ProtocolBase.TIMELOCK;
        if(_chainId == 146) return ProtocolSonic.TIMELOCK;
        
        revert AddressNotFound(_chainId);
    }

    function getGoatSwapper(uint256 _chainId) external pure returns (address) {
        if(_chainId == 42161) return ProtocolArbitrum.GOAT_SWAPPER;
        if(_chainId == 146) return ProtocolSonic.GOAT_SWAPPER;

        revert AddressNotFound(_chainId);
    }

    function getUtilities(uint256 _chainId, bytes32 _utilityName) external pure returns (address) {
        if(_utilityName == keccak256("CURVE_STABLENG_SLIPPAGE_UTILITY")) {
            if(_chainId == 42161) return UtilitiesArbitrum.CURVE_STABLENG_SLIPPAGE_UTILITY;
        }

        revert AddressNotFound(_chainId);
    }

    function getWrappedGas(uint256 _chainId) external pure returns (address) {
        if(_chainId == 42161) return AssetsArbitrum.WETH;
        if(_chainId == 146) return AssetsSonic.WS;

        revert AddressNotFound(_chainId);
    }
}