// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import "forge-std/Test.sol";
import { FeeConfigurator } from "src/infra/FeeConfigurator.sol";

contract FeeConfiguratorTest is Test {

    error InvalidInitialization();

    /*//////////////////////////////////////////////////////////////////////////
                                   TEST CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/

    FeeConfigurator feeConfig;

    /*//////////////////////////////////////////////////////////////////////////
                                  SET-UP FUNCTION
    //////////////////////////////////////////////////////////////////////////*/

    function setUp() public virtual {
        feeConfig = new FeeConfigurator();
        feeConfig.initialize(address(this), 0.05 ether);
    }

    function test_FeeCategory() public {
        feeConfig.setFeeCategory(
            0,
            0.05 ether,
            0 ether,
            0.01 ether,
            "default",
            true,
            true
        );

        feeConfig.setStratFeeId(0);

        assertEq(feeConfig.getFees(address(this), true).strategist, 0.01 ether);
    }    
}
