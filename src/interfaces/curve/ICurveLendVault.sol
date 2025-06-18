// SPDX-License-Identifier: GNU AGPLv3

pragma solidity 0.8.27;

import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";

interface ICurveLendVault is IERC4626 {
    function controller() external view returns (address);
}