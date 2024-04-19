// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import { MockERC20 } from "solmate/test/utils/mocks/MockERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { GoatVaultFactory } from "src/infra/vault/GoatVaultFactory.sol";
import { BoostFactory } from "src/infra/boost/BoostFactory.sol";
import { GoatBoost } from "src/infra/boost/GoatBoost.sol";
import { IGoatBoost } from "interfaces/infra/IGoatBoost.sol";

contract BoostTestBase is Test {
    /*//////////////////////////////////////////////////////////////////////////
                                   CONSTANTS
    //////////////////////////////////////////////////////////////////////////*/

    address internal constant OWNER = address(0x01);
    address internal constant TREASURY = address(0x02);
    address internal constant MANAGER = TREASURY;
    uint256 internal constant BOOST_DURATION = 7 days;

    /*//////////////////////////////////////////////////////////////////////////
                                   VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    GoatVaultFactory internal vaultFactory;
    BoostFactory internal boostFactory;
    IGoatBoost internal boost;
    IERC20 internal stakedToken;
    IERC20 internal rewardToken;
    address private boostImpl;

    /*//////////////////////////////////////////////////////////////////////////
                                  SET-UP FUNCTION
    //////////////////////////////////////////////////////////////////////////*/

    function setUp() public virtual {
        vaultFactory = new GoatVaultFactory(address(0));
        boostImpl = address(new GoatBoost());
        boostFactory = new BoostFactory(address(vaultFactory), boostImpl);

        stakedToken = IERC20(address(new MockERC20("gToken", "GTKN", 18)));
        rewardToken = IERC20(address(new MockERC20("Reward Token", "RWRD", 18)));

        boost = IGoatBoost(boostFactory.deployBoost(
            address(stakedToken),
            address(rewardToken),
            BOOST_DURATION,
            MANAGER,
            TREASURY
        ));
    }

    function airdropStakedTokens(address _account, uint256 _amount) internal {
        deal(_account, 1 ether);
        deal(address(stakedToken), _account, _amount);
    }
}