    // SPDX-License-Identifier: AGPL-3.0
    pragma solidity >=0.8.0 <0.9.0;
    
    import {CryticERC4626PropertyTests} from "properties/ERC4626/ERC4626PropertyTests.sol";
    // this token _must_ be the vault's underlying asset
    import {ERC20Mock} from "../../../mocks/erc20/ERC20Mock.sol";
    // change to your vault implementation
    import {Multistrategy} from "src/infra/multistrategy/Multistrategy.sol";

    contract MultistrategyERC4626Harness is CryticERC4626PropertyTests {
        address manager = address(5);
        address feeRecipient = address(6);
        constructor () {
            ERC20Mock _asset = new ERC20Mock("DAI", "DAI");
            Multistrategy _vault = new Multistrategy(address(_asset), manager, feeRecipient, "Goat DAI", "gDAI");
            initialize(address(_vault), address(_asset), false);
        }
    }