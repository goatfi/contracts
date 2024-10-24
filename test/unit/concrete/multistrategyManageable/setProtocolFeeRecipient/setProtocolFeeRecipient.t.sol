// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.20 <0.9.0;

import { Multistrategy_Unit_Shared_Test } from "../../../shared/Multistrategy.t.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Errors } from "src/infra/libraries/Errors.sol";

contract SetProtocolFeeRecipient_Unit_Concrete_Test is Multistrategy_Unit_Shared_Test {
    function test_RevertWhen_CallerNotOwner() external {
        // Change caller to bob
        swapCaller(users.bob);
        
        // Expect a revert
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, users.bob));
        multistrategy.setProtocolFeeRecipient(users.feeRecipient);
    }

    modifier whenCallerIsOwner() {
        _;
    }

    function test_RevertWhen_ZeroAddress() 
        external
        whenCallerIsOwner
    {
        // Expect a revert
        vm.expectRevert(abi.encodeWithSelector(Errors.ZeroAddress.selector));
        multistrategy.setProtocolFeeRecipient(address(0));
    }

    modifier whenNotZeroAddress() {
        _;
    }

    function test_SetProtocolFeeRecipient_SameFeeRecipient() 
        external 
        whenCallerIsOwner 
        whenNotZeroAddress
    {
        // Expect the relevant event to be emitted.
        vm.expectEmit({ emitter: address(multistrategy) });
        emit ProtocolFeeRecipientSet({ protocolFeeRecipient: users.feeRecipient });

        // Set the protocol fee recipient
        multistrategy.setProtocolFeeRecipient(users.feeRecipient);

        // Assert the protocol fee recipient has been set
        address actualFeeRecipient = multistrategy.protocolFeeRecipient();
        address expectedFeeRecipient = users.feeRecipient;
        assertEq(actualFeeRecipient, expectedFeeRecipient, "protocol fee recipient");
    }

    function test_SetProtocolFeeRecipient_NewFeeRecipient()
        external
        whenCallerIsOwner
        whenNotZeroAddress
    {
        // Expect the relevant event to be emitted.
        vm.expectEmit({ emitter: address(multistrategy) });
        emit ProtocolFeeRecipientSet({ protocolFeeRecipient: users.bob });

        // Set the protocol fee recipient
        multistrategy.setProtocolFeeRecipient(users.bob);

        // Assert the protocol fee recipient has been set
        address actualFeeRecipient = multistrategy.protocolFeeRecipient();
        address expectedFeeRecipient = users.bob;
        assertEq(actualFeeRecipient, expectedFeeRecipient, "protocol fee recipient");
    }
}