// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.20 <0.9.0;

import { IERC4626, Multistrategy_Integration_Shared_Test } from "../../../shared/Multistrategy.t.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import { StrategyAdapterMock } from "../../../../mocks/StrategyAdapterMock.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";
import { Errors } from "src/infra/libraries/Errors.sol";

contract RequestCredit_Integration_Concrete_Test is Multistrategy_Integration_Shared_Test {
    StrategyAdapterMock strategy;
    uint8 decimals;

    function setUp() public virtual override {
        Multistrategy_Integration_Shared_Test.setUp();
        decimals = IERC20Metadata(IERC4626(address(multistrategy)).asset()).decimals();
    }

    function test_RevertWhen_ContractIsPaused() external {
        // Pause the multistrategy
        multistrategy.pause();

        // Expect a revert
        vm.expectRevert(abi.encodeWithSelector(Pausable.EnforcedPause.selector));
        multistrategy.requestCredit();
    }

    modifier whenContractNotPaused() {
        _;
    }

    function test_RevertWhen_CallerNotActiveStrategy()
        external
        whenContractNotPaused    
    {   
        // Expect a revert
        vm.expectRevert(abi.encodeWithSelector(Errors.StrategyNotActive.selector, users.owner));
        multistrategy.requestCredit();
    }

    modifier whenCallerActiveStrategy() {
        strategy = deployMockStrategyAdapter(address(multistrategy), IERC4626(address(multistrategy)).asset());
        multistrategy.addStrategy(address(strategy), 5_000, 0, 100_000 * 10 ** decimals);

        triggerUserDeposit(users.bob, 1_000 * 10 ** decimals);
        _;
    }

    function test_RequestCredit_NoAvailableCredit()
        external
        whenContractNotPaused
        whenCallerActiveStrategy
    {   
        //Set the debtRatio to 0 so there isn't any credit available
        multistrategy.setStrategyDebtRatio(address(strategy), 0);
        swapCaller(address(strategy));

        uint256 actualCredit = multistrategy.requestCredit();

        uint256 expectedCredit = 0;
        assertEq(actualCredit, expectedCredit, "requestCredit, credit");

        uint256 actualMultistrategyBalance = asset.balanceOf(address(multistrategy));
        uint256 expectedMultistrategyBalance = 1_000 * 10 ** decimals;
        assertEq(actualMultistrategyBalance, expectedMultistrategyBalance, "requestCredit, no availableCredit, multistrategy balance");

        uint256 actualStrategyBalance = asset.balanceOf(address(strategy));
        uint256 expectedStrategyBalance = 0;
        assertEq(actualStrategyBalance, expectedStrategyBalance, "requestCredit, no availableCredit, strategy balance");
    }

    modifier whenCreditAvailable() {
        _;
    }

    function test_RequestCredit() 
        external
        whenContractNotPaused
        whenCallerActiveStrategy
        whenCreditAvailable
    {
        swapCaller(address(strategy));

        uint256 actualCredit = multistrategy.requestCredit();

        uint256 expectedCredit = 500 * 10 ** decimals;
        assertEq(actualCredit, expectedCredit, "requestCredit, credit");

        uint256 actualMultistrategyBalance = asset.balanceOf(address(multistrategy));
        uint256 expectedMultistrategyBalance = 500 * 10 ** decimals;
        assertEq(actualMultistrategyBalance, expectedMultistrategyBalance, "requestCredit, multistrategy balance");

        uint256 actualStrategyBalance = asset.balanceOf(address(strategy));
        uint256 expectedStrategyBalance = 500 * 10 ** decimals;
        assertEq(actualStrategyBalance, expectedStrategyBalance, "requestCredit, strategy balance");
    }
}