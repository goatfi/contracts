// SPDX-License-Identifier: MIT
pragma solidity^0.8.20;

import { DeployAdapterBase } from "../../DeployAdapterBase.sol";
import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import { ICurveGaugeFactory } from "interfaces/curve/ICurveGaugeFactory.sol";
import { IProtocolController} from "interfaces/stakedao/IProtocolController.sol";
import { CurveLendSDV2Adapter } from "src/infra/multistrategy/adapters/CurveLendSDV2Adapter.sol";
import { StrategyAdapterHarvestable } from "src/abstracts/StrategyAdapterHarvestable.sol";
import { Addressbook } from "@addressbook/AddressBook.sol";

/// @title Deploys a Curve Lend Adapter staked on StakeDAO
contract DeployCurveLendSDV2Adapter is DeployAdapterBase {
    Addressbook addressbook = new Addressbook();

    function run(
        address multistrategy,
        string memory name, 
        address curve_lend_vault,
        address[] memory rewards
    ) public {

        address asset = IERC4626(multistrategy).asset();
        address manager = addressbook.getManager(block.chainid);
        address guardian = addressbook.getGuardian(block.chainid);
        address stake_dao_vault = getStakeDaoVault(curve_lend_vault);

        _verifyRewards(rewards, asset);
        require(IERC4626(stake_dao_vault).asset() == curve_lend_vault, "Stake DAO Vault mismatch");

        StrategyAdapterHarvestable.HarvestAddresses memory harvestAddresses = StrategyAdapterHarvestable.HarvestAddresses({
            swapper: addressbook.getGoatSwapper(block.chainid),
            wrappedGas: addressbook.getWrappedGas(block.chainid)
        });

        CurveLendSDV2Adapter.CurveLendSDV2Addresses memory crvLendSDV2Addresses = CurveLendSDV2Adapter.CurveLendSDV2Addresses({
            lendVault: curve_lend_vault,
            sdVault: stake_dao_vault
        });

        vm.startBroadcast();

        CurveLendSDV2Adapter adapter = new CurveLendSDV2Adapter(multistrategy, asset, harvestAddresses, crvLendSDV2Addresses, name, "CRV-LEND-SDV2");

        for(uint i = 0; i < rewards.length; ++i) {
            adapter.addReward(rewards[i]);
        }

        adapter.enableGuardian(guardian);
        adapter.transferOwnership(manager);

        vm.stopBroadcast();

        _postDeploymentCheck(multistrategy, address(adapter));
    }

    function getGaugeFactory(uint256 chainId) private pure returns (address) {
        if (chainId == 42161) return 0xabC000d88f23Bb45525E447528DBF656A9D55bf5; // Arbitrum
        revert("Unsupported network");
    }

    function getStakeDAOProtocolController(uint256 chainId) private pure returns (address) {
        if (chainId == 42161) return 0x2d8BcE1FaE00a959354aCD9eBf9174337A64d4fb; // Arbitrum
        revert("Unsupported network");
    }

    function getStakeDaoVault(address _curveLendVault) private view returns (address) {
        address gauge_factory = getGaugeFactory(block.chainid);
        address gauge = ICurveGaugeFactory(gauge_factory).get_gauge_from_lp_token(_curveLendVault);
        address stake_dao_protocol_controller = getStakeDAOProtocolController(block.chainid);
        return IProtocolController(stake_dao_protocol_controller).gauge(gauge).vault;
    }
}