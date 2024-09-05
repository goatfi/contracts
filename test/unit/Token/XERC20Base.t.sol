// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { GOA } from "src/infra/GOA.sol";
import { XERC20Factory } from "@xerc20/contracts/XERC20Factory.sol";
import { IXERC20 } from "@xerc20/interfaces/IXERC20.sol"; 
import { IXERC20Factory } from "@xerc20/interfaces/IXERC20Factory.sol";
import { IXERC20Lockbox } from "@xerc20/interfaces/IXERC20Lockbox.sol";

contract XERC20TestBase is Test {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////////////////
                                   CONSTANTS
    //////////////////////////////////////////////////////////////////////////*/

    address internal constant TREASURY = 0x7bC668564aF23c2a26cbE50fAeE034B2e034fABc;
    address internal constant USER = 0x80A74Ab94E8a5ca4F1C81ad21e89A450aD8828b0;
    uint internal constant USER_INITIAL_BALANCE = 1000 ether;

    /*//////////////////////////////////////////////////////////////////////////
                                   VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    uint256[] internal minterLimits = new uint256[](2);
    uint256[] internal burnerLimits = new uint256[](2);
    address[] internal bridgeAdapters = new address[](2);

    /*//////////////////////////////////////////////////////////////////////////
                                   TEST CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/

    IERC20 internal goa;
    IXERC20 internal xGoa;
    IERC20 internal erc20xGoa;
    IXERC20Factory internal xerc20Factory;
    IXERC20Lockbox internal lockbox;

    /*//////////////////////////////////////////////////////////////////////////
                                  SET-UP FUNCTION
    //////////////////////////////////////////////////////////////////////////*/

    /**
     * @dev Deploy GOA, and xERC20 Factory. Create xGOA and the lockbox. Send the user 1000 GOA
     */

    function setUp() public virtual {
        goa = new GOA(TREASURY);
        xerc20Factory = new XERC20Factory();
        xGoa = IXERC20(xerc20Factory.deployXERC20("X GOA", "xGOA", minterLimits, burnerLimits, bridgeAdapters));
        lockbox = IXERC20Lockbox(xerc20Factory.deployLockbox(address(xGoa), address(goa), false));

        erc20xGoa = IERC20(address(xGoa));

        vm.prank(TREASURY);
        goa.safeTransfer(USER, USER_INITIAL_BALANCE);
    }
}
