// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

library ProtocolBase {
  // https://basescan.org/address/0x663c8a709cDc448B657D09F0b5635F22F8e7e42f
  address internal constant TREASURY = 0x663c8a709cDc448B657D09F0b5635F22F8e7e42f;

  // https://basescan.org/address/0x108e823a26C5FB096D1f7c493809ccE9015507a6
  address internal constant TIMELOCK = 0x108e823a26C5FB096D1f7c493809ccE9015507a6;

  // https://basescan.org/address/0x77dF091585e587B3b8e717F75A6A6a7Bc6698B39
  address internal constant FEE_CONFIG = 0x77dF091585e587B3b8e717F75A6A6a7Bc6698B39;

  // https://basescan.org/address/0xE06f5E3039901C1C16C7044fd3238987db8e688a
  address internal constant MULTICALL = 0xE06f5E3039901C1C16C7044fd3238987db8e688a;

  // https://basescan.org/address/0x901e3059Bf118AbC74d917440F0C08FC78eC0Aa6
  address internal constant GOAT_APP_MULTICALL = 0x901e3059Bf118AbC74d917440F0C08FC78eC0Aa6;

  // https://basescan.org/address/0xBBfF676BD929d5aA32d352D9D7E86930dE603048
  address internal constant GOAT_VAULT_FACTORY = 0xBBfF676BD929d5aA32d352D9D7E86930dE603048;

  // https://basescan.org/address/0x96F1184f198D4005A5675393cB5C6734Bc68D7eD
  address internal constant GOAT_BOOST_FACTORY = 0x96F1184f198D4005A5675393cB5C6734Bc68D7eD;

  // https://basescan.org/address/0x6F91b345E36FC451893FA1B3873Cd30A15aE8F18
  address internal constant GOAT_SWAPPER = 0x6F91b345E36FC451893FA1B3873Cd30A15aE8F18;
}