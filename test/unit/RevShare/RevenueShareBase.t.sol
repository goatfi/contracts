// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { GOA } from "src/infra/GOA.sol";
import { WETH } from "lib/common/weth/WETH.sol";
import { GoatFeeBatch } from "src/infra/GoatFeeBatch.sol";
import { GoatRewardPool } from "src/infra/GoatRewardPool.sol";

contract RevenueShareTestBase is Test {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////////////////
                                   CONSTANTS
    //////////////////////////////////////////////////////////////////////////*/

    uint256 internal constant TREASURY_FEE = 0;
    address internal constant TREASURY = 0x7bC668564aF23c2a26cbE50fAeE034B2e034fABc;
    address internal constant HARVESTER = 0x4a4b74072AA2A8813324126eDC219621591f723D;
    address internal constant BLACKHAT = 0xB1aC5eFE6aC252CA5EE510bEc9920fb6A48a9988;


    /*//////////////////////////////////////////////////////////////////////////
                                   TEST CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/

    GoatFeeBatch internal feeBatch;
    GoatRewardPool internal rewardPool;
    GOA internal goa;
    WETH internal weth;

    /*//////////////////////////////////////////////////////////////////////////
                                  SET-UP FUNCTION
    //////////////////////////////////////////////////////////////////////////*/

    function setUp() public virtual {
        goa = new GOA(TREASURY);
        weth = new WETH();
        rewardPool = new GoatRewardPool(address(goa));
        feeBatch = new GoatFeeBatch(address(weth), address(rewardPool), TREASURY, TREASURY_FEE);

        rewardPool.setWhitelist(address(feeBatch), true);
    }
}
