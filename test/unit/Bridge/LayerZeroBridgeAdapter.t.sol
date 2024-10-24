// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "forge-std/console.sol";
import { XERC20TestBase } from "../Token/XERC20Base.t.sol";
import { RemoteXERC20 } from "test-utils/RemoteXERC20.sol";
import { ILayerZeroEndpoint } from "@layerzero/lzApp/interfaces/ILayerZeroEndpoint.sol";
import { LZEndpointMock } from "@layerzero/lzApp/mocks/LZEndpointMock.sol";
import { LayerZeroBridgeAdapter} from "src/infra/bridgeAdapter/LayerZeroBridgeAdapter.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IXERC20Lockbox } from "@xerc20/interfaces/IXERC20Lockbox.sol";

contract LayerZeroBridgeAdapterTest is XERC20TestBase, RemoteXERC20 {

    /*//////////////////////////////////////////////////////////////////////////
                                   CONSTANTS
    //////////////////////////////////////////////////////////////////////////*/

    uint256 private constant BASE_FEE = 1 gwei;

    /*//////////////////////////////////////////////////////////////////////////
                                   VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    address[] org_neededContracts = new address[](1);
    address[] dst_neededContracts = new address[](1);
    uint256[] chainIds = [1, 10];
    uint16[] lzIds = [101, 111];

    /*//////////////////////////////////////////////////////////////////////////
                                   TEST CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/
    
    LZEndpointMock org_endpoint;
    LZEndpointMock dst_endpoint;
    LayerZeroBridgeAdapter org_bridgeAdapter;
    LayerZeroBridgeAdapter dst_bridgeAdapter;

    /*//////////////////////////////////////////////////////////////////////////
                                    EVENTS
    //////////////////////////////////////////////////////////////////////////*/

    event BridgeError(uint256 indexed errorId, address indexed user, uint256 amount, uint256 timestamp);

    /*//////////////////////////////////////////////////////////////////////////
                                  SET-UP FUNCTION
    //////////////////////////////////////////////////////////////////////////*/

    /**
     * @notice Deploys two bridge adapters and two endpoints. Initializes the bridge adapters.
     * @dev Endpoint is deployed with a LayerZero chain Id (lzId). Bridge adapter works with chainId,
     * so all calls to
     */

    function setUp() public virtual override {
        XERC20TestBase.setUp();
        RemoteXERC20.createRemoteXERC20();

        org_endpoint = new LZEndpointMock(lzIds[0]);
        dst_endpoint = new LZEndpointMock(lzIds[1]);

        org_bridgeAdapter = new LayerZeroBridgeAdapter();
        dst_bridgeAdapter = new LayerZeroBridgeAdapter();

        minterLimits[0] = 100_000 ether;
        burnerLimits[0] = 100_000 ether;
        bridgeAdapters[0] = address(org_bridgeAdapter);
        bridgeAdapters[1] = address(dst_bridgeAdapter);

        org_neededContracts[0] = address(org_endpoint);
        dst_neededContracts[0] = address(dst_endpoint);

        org_bridgeAdapter.initialize(goa, xGoa, lockbox, org_neededContracts);
        org_bridgeAdapter.addChainIds(chainIds, lzIds);
        org_bridgeAdapter.setTrustedRemote(_getLzId(chainIds[1]), abi.encodePacked(bridgeAdapters[1], bridgeAdapters[0]));
        org_bridgeAdapter.setGasLimit(200_000);

        dst_bridgeAdapter.initialize(IERC20(address(d_xGoa)), d_xGoa, IXERC20Lockbox(address(0)), dst_neededContracts);
        dst_bridgeAdapter.addChainIds(chainIds, lzIds);
        dst_bridgeAdapter.setTrustedRemote(_getLzId(chainIds[0]), abi.encodePacked(bridgeAdapters[0], bridgeAdapters[1]));
        dst_bridgeAdapter.setGasLimit(200_000);

        org_endpoint.setDestLzEndpoint(address(dst_bridgeAdapter), address(dst_endpoint));
        dst_endpoint.setDestLzEndpoint(address(org_bridgeAdapter), address(org_endpoint));

        xGoa.setLimits(bridgeAdapters[0], minterLimits[0], burnerLimits[0]);
        d_xGoa.setLimits(bridgeAdapters[1], minterLimits[0], burnerLimits[0]);

        vm.fee(BASE_FEE);
    }

    function test_RevertWhen_InitializingSecondTime() public {
        vm.expectRevert();
        org_bridgeAdapter.initialize(goa, xGoa, lockbox, org_neededContracts);
    }

    function test_TrustedRemote() public {
        bytes memory org_trustedRemote = org_bridgeAdapter.getTrustedRemoteAddress(_getLzId(chainIds[1]));
        bytes memory dst_trustedRemote = dst_bridgeAdapter.getTrustedRemoteAddress(_getLzId(chainIds[0]));

        assertEq(org_trustedRemote, abi.encodePacked(bridgeAdapters[1]));
        assertEq(dst_trustedRemote, abi.encodePacked(bridgeAdapters[0]));
    }

    function test_Bridge() public {
        vm.startPrank(USER);
        vm.deal(USER, 1 ether);

        goa.approve(address(org_bridgeAdapter), 10 ether);
        org_bridgeAdapter.bridge{value: 0.1 ether}(chainIds[1], 10 ether, USER);

        assertEq(goa.balanceOf(USER), 990 ether);
        assertEq(goa.balanceOf(address(lockbox)), 10 ether);
        assertEq(d_erc20xGoa.balanceOf(USER), 10 ether);
    }

    function test_BridgeBack() public {
        //Bridge to Destination
        vm.startPrank(USER);
        vm.deal(USER, 1 ether);

        goa.approve(address(org_bridgeAdapter), 10 ether);
        org_bridgeAdapter.bridge{value: 0.1 ether}(chainIds[1], 10 ether, USER);

        //Bridge Back
        d_erc20xGoa.approve(address(dst_bridgeAdapter), 10 ether);
        dst_bridgeAdapter.bridge{value: 0.1 ether}(chainIds[0], 10 ether, USER);

        assertEq(goa.balanceOf(USER), USER_INITIAL_BALANCE);
        assertEq(goa.balanceOf(address(lockbox)), 0 ether);
        assertEq(d_erc20xGoa.balanceOf(USER), 0 ether);
    }

    function test_RevertWhen_BridgeToWrongChain() public {
        vm.startPrank(USER);
        vm.deal(USER, 1 ether);

        goa.approve(address(org_bridgeAdapter), 10 ether);
        vm.expectRevert("LzApp: destination chain is not a trusted source");
        org_bridgeAdapter.bridge{value: 0.1 ether}(500, 10 ether, USER);
    }

    function test_RevertWhen_NoFundsToBridge() public {
        //Bridge to Destination
        vm.startPrank(USER);
        vm.deal(USER, 1 ether);

        goa.approve(address(org_bridgeAdapter), 10_000 ether);
        vm.expectRevert();
        org_bridgeAdapter.bridge{value: 0.1 ether}(chainIds[1], 10_000 ether, USER);
    }

    function test_ExcessETHSentBackToUser() public {
        vm.startPrank(USER);
        vm.deal(USER, 1 ether);

        goa.approve(address(org_bridgeAdapter), 10 ether);
        org_bridgeAdapter.bridge{value: 0.1 ether}(chainIds[1], 10 ether, USER);

        //Bridge should only cost a bit less than 0.02 ether.
        assertGt(USER.balance, 0.95 ether);
    }

    function test_RevertWhen_NotSendingEnoughETHToBridge() public {
        vm.startPrank(USER);
        vm.deal(USER, 1 ether);

        goa.approve(address(org_bridgeAdapter), 10 ether);
        vm.expectRevert("LayerZeroMock: not enough native for fees");
        org_bridgeAdapter.bridge{value: 0.01 ether}(chainIds[1], 10 ether, USER);
    }

    function test_BridgeWithExactEstimatedFees() public {
        vm.startPrank(USER);
        vm.deal(USER, 1 ether);

        bytes memory payload = abi.encode(USER, 10 ether);
        bytes memory adapterParams = abi.encodePacked(uint16(1), dst_bridgeAdapter.gasLimit());
        (uint256 estimatedFee, ) = org_endpoint.estimateFees(_getLzId(chainIds[1]), address(dst_bridgeAdapter), payload, false, adapterParams);

        goa.approve(address(org_bridgeAdapter), 10 ether);
        org_bridgeAdapter.bridge{value: estimatedFee}(chainIds[1], 10 ether, USER);

        assertEq(goa.balanceOf(USER), 990 ether);
        assertEq(d_erc20xGoa.balanceOf(USER), 10 ether);
        assertEq(estimatedFee, 1 ether - USER.balance);
    }

    function test_NotEnoughGasToPayOnDestination() public {
        //Forge gas reports estimate that lzReceive needs about 90K gas to complete the tx.
        org_bridgeAdapter.setGasLimit(60_000);
        dst_bridgeAdapter.setGasLimit(60_000);
        vm.startPrank(USER);
        vm.deal(USER, 1 ether);
        goa.approve(address(org_bridgeAdapter), 10 ether);

        bytes memory path = abi.encodePacked(address(org_bridgeAdapter), address(dst_bridgeAdapter));
        bytes memory payload = abi.encode(USER, 10 ether);
        bytes memory adapterParams = abi.encodePacked(uint16(1), dst_bridgeAdapter.gasLimit());
        (uint256 estimatedFee, ) = org_endpoint.estimateFees(_getLzId(chainIds[1]), address(dst_bridgeAdapter), payload, false, adapterParams);

        /**
         * Gas fee shouldn't be enough to pay for the tx on destination.
         * But the transaction should revert, as the error gets stored.
         */
        org_bridgeAdapter.bridge{value: estimatedFee}(chainIds[1], 10 ether, USER);

        //Assert that the user got deducted on origin but didn't receive on destination
        assertEq(goa.balanceOf(USER), 990 ether);
        assertEq(d_erc20xGoa.balanceOf(USER), 0 ether);

        dst_endpoint.retryPayload(_getLzId(chainIds[0]), path, payload);

        assertEq(d_erc20xGoa.balanceOf(USER), 10 ether);
    }

    function test_NotEnoughLimitsToMintOnDestination() public {
        vm.prank(TREASURY);
        goa.transfer(USER, 109_000 ether);

        //Set higher burner limits on orgigin as we want to test the fail on destination.
        xGoa.setLimits(bridgeAdapters[0], minterLimits[0], burnerLimits[0] * 2);


        //Now the user has more GOA than the Bridge can mint.

        vm.startPrank(USER);
        vm.deal(USER, 1 ether);
        goa.approve(address(org_bridgeAdapter), type(uint256).max);
        org_bridgeAdapter.bridge{value: 0.02 ether}(chainIds[1], 60_000 ether, USER);

        assertEq(goa.balanceOf(USER), 50_000 ether);
        assertEq(d_erc20xGoa.balanceOf(USER), 60_000 ether);

        vm.expectEmit(true, true, true, false);
        emit BridgeError(0, USER, 50_000 ether, 1);
        org_bridgeAdapter.bridge{value: 0.02 ether}(chainIds[1], 50_000 ether, USER);

        assertEq(goa.balanceOf(USER), 0 ether);
        assertEq(d_erc20xGoa.balanceOf(USER), 60_000 ether);

        vm.warp(block.timestamp + 1 days);

        //Retry the failed bridge after the limits have been reset
        dst_bridgeAdapter.retry(0);

        assertEq(d_erc20xGoa.balanceOf(USER), 110_000 ether);
    }

    /**
     * @dev In the setup, can only be called after bridgeAdapter.addChainIds().
     * @param _chainId Chain Id we want to get the lzId form.
     */
    function _getLzId(uint256 _chainId) private view returns(uint16) {
        return org_bridgeAdapter.chainIdToLzId(_chainId);
    }
}
