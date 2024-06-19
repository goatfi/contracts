// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.20 <0.9.0;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { MultistrategyHarness_Integration_Shared_Test } from "../../../shared/MultistrategyHarness.t.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

contract ShareValue_Integration_Concrete_Test is MultistrategyHarness_Integration_Shared_Test {
    uint256 shares = 100 ether;
    function test_ShareValue_ZeroTotalSupply() external {
        // Assert share value is zero when totalSupply is 0
        uint256 actualShareValue = multistrategyHarness.shareValue(shares);
        uint256 expectedShareValue = shares;
        assertEq(actualShareValue, expectedShareValue, "shareValue");
    }

    modifier whenTotalSupplyNotZero() {
        triggerUserDeposit(users.bob, 1000 ether);
        _;
    }

    function test_ShareValue_ZeroSharesAmount() 
        external
        whenTotalSupplyNotZero
    {
        // Assert share value is zero when amount of shares is 0
        uint256 actualShareValue = multistrategyHarness.shareValue(0);
        uint256 expectedShareValue = 0;
        assertEq(actualShareValue, expectedShareValue, "shareValue");
    }

    modifier whenSharesAmountNotZero() {
        _;
    }

    function test_ShareValue()
        external
        whenTotalSupplyNotZero
        whenSharesAmountNotZero
    {
        uint256 freeFunds = multistrategyHarness.freeFunds();
        uint256 totalSupply = IERC20(address(multistrategyHarness)).totalSupply();

        // Assert share value is the amount of shares multiplied by freeFunds, divided by totalSupply
        uint256 actualShareValue = multistrategyHarness.shareValue(shares);
        uint256 expectedShareValue = Math.mulDiv(shares, freeFunds, totalSupply);
        assertEq(actualShareValue, expectedShareValue, "shareValue");
    }
}