// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { XERC20Factory } from "@xerc20/contracts/XERC20Factory.sol";
import { IXERC20 } from "@xerc20/interfaces/IXERC20.sol"; 
import { IXERC20Factory } from "@xerc20/interfaces/IXERC20Factory.sol";

contract RemoteXERC20 {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////////////////
                                   VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    uint256[] internal d_minterLimits = new uint256[](1);
    uint256[] internal d_burnerLimits = new uint256[](1);
    address[] internal d_bridges = new address[](1);

    /*//////////////////////////////////////////////////////////////////////////
                                   TEST CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/

    IXERC20 internal d_xGoa;
    IERC20 internal d_erc20xGoa;
    IXERC20Factory internal d_factory;

    /*//////////////////////////////////////////////////////////////////////////
                                  SET-UP FUNCTION
    //////////////////////////////////////////////////////////////////////////*/

    /**
     * @dev Deploy GOA, and xERC20 Factory. Create xGOA and the lockbox. Send the user 1000 GOA
     */

    function createRemoteXERC20() public virtual {
        d_factory = new XERC20Factory();
        d_xGoa = IXERC20(d_factory.deployXERC20("X GOA", "xGOA", d_minterLimits, d_burnerLimits, d_bridges));
        d_erc20xGoa = IERC20(address(d_xGoa));
    }
}
