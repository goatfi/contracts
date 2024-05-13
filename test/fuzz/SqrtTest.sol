// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import { ABDKMath64x64 } from "lib/common/ABDKMath64x64.sol";

contract SqrtTest is Test {
    /// forge-config: default.fuzz.runs = 2048
    function testFuzz_ABDKSqrt(uint256 input) public pure {
        uint256 sqrt = ABDKMath64x64.sqrtu(input);
        assert(sqrt < 2**128); // 2**128 == sqrt(2^256)
        // since we compute floor(sqrt(input))
        assert(sqrt**2 <= input);
        unchecked{
            assert((sqrt + 1)**2 > input || sqrt == type(uint128).max);
        }
    }
    /// forge-config: default.fuzz.runs = 2048
    function testFuzz_SimpleSqrt(uint256 input) public pure {
        uint256 sqrt = simpleSqrt(input);
        assert(sqrt < 2**128); // 2**128 == sqrt(2^256)
        // since we compute floor(sqrt(input))
        assert(sqrt**2 <= input);
        unchecked{
            assert((sqrt + 1)**2 > input || sqrt == type(uint128).max);
        }
    }

    function simpleSqrt(uint256 y) private pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }
}