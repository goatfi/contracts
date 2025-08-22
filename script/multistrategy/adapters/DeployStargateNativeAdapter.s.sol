// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import { IStargateV2Chef, IStargateV2Router } from "interfaces/stargate/IStargate.sol";
import { StargateAdapterNative } from "src/infra/multistrategy/adapters/StargateAdapterNative.sol";
import { StrategyAdapterHarvestable } from "src/abstracts/StrategyAdapterHarvestable.sol";
import { Addressbook } from "@addressbook/AddressBook.sol";

/// @title Deploys an Stargate Adapter for ETH
contract DeployStargateNativeAdapter is Script {
    Addressbook addressbook = new Addressbook();

    function run(
        address multistrategy,
        string memory name,
        address stargate_router,
        address[] memory rewards
    ) public {

        require(multistrategy != address(0), "Multistrategy cannot be zero address");

        address asset = IERC4626(multistrategy).asset();
        address manager = addressbook.getManager(block.chainid);
        address guardian = addressbook.getGuardian(block.chainid);
        address stargate_chef = getChef(block.chainid);

        require(asset == IStargateV2Router(stargate_router).token(), "Router underlying asset mismatch");
        require(assetIncludedInChef(stargate_router, stargate_chef), "Chef does not include the asset");

        StrategyAdapterHarvestable.HarvestAddresses memory harvestAddresses = StrategyAdapterHarvestable.HarvestAddresses({
            swapper: addressbook.getGoatSwapper(block.chainid),
            wrappedGas: addressbook.getWrappedGas(block.chainid)
        });

        StargateAdapterNative.StargateAddresses memory stargateAddresses = StargateAdapterNative.StargateAddresses({
            router: stargate_router,
            chef: stargate_chef
        });

        vm.startBroadcast();

        StargateAdapterNative adapter = new StargateAdapterNative(
            multistrategy,
            asset,
            harvestAddresses,
            stargateAddresses,
            name,
            "STARGATE"
        );

        for (uint i = 0; i < rewards.length; ++i) {
            adapter.addReward(rewards[i]);
        }

        adapter.enableGuardian(guardian);
        adapter.transferOwnership(manager);

        vm.stopBroadcast();
    }

    function getChef(uint256 chainId) public pure returns (address) {
        if (chainId == 42161) return 0x3da4f8E456AC648c489c286B99Ca37B666be7C4C; // Arbitrum
        revert("Unsupported network");
    }

    function assetIncludedInChef(address router, address chef) public view returns (bool) {
        address lpToken = IStargateV2Router(router).lpToken();
        address[] memory tokens = IStargateV2Chef(chef).tokens();
        for(uint256 i = 0; i < tokens.length; ++i) {
            if(tokens[i] == lpToken) return true;
        }
        return false;
    }
}
