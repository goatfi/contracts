// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { Base_Test } from "../../../Base.t.sol";
import { FeeConfigurator } from "src/infra/FeeConfigurator.sol";

contract FeeConfiguratorTest is Base_Test {
    /*//////////////////////////////////////////////////////////////////////////
                                   TEST CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/

    FeeConfigurator feeConfig;

    /*//////////////////////////////////////////////////////////////////////////
                                  SET-UP FUNCTION
    //////////////////////////////////////////////////////////////////////////*/

    function setUp() public virtual override {
        super.setUp();

        feeConfig = new FeeConfigurator();
        feeConfig.initialize(address(this), 0.05 ether);

        vm.label({
            account: address(feeConfig),
            newLabel: "GoatFeeConfigurator"
        });
    }
}
