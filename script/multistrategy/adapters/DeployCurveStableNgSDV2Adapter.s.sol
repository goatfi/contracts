// SPDX-License-Identifier: MIT
pragma solidity^0.8.20;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import { ICurveLiquidityPool } from "interfaces/curve/ICurveLiquidityPool.sol";
import { ICurveGaugeFactory } from "interfaces/curve/ICurveGaugeFactory.sol";
import { IProtocolController} from "interfaces/stakedao/IProtocolController.sol";
import { StrategyAdapterHarvestable } from "src/abstracts/StrategyAdapterHarvestable.sol";
import { CurveStableNgSDV2Adapter } from "src/infra/multistrategy/adapters/CurveStableNgSDV2Adapter.sol";
import { Addressbook } from "@addressbook/AddressBook.sol";

/// @title Deploys a Curve StableNg Liquidity Pool Adapter staked on StakeDAO
contract DeployCurveStableNgSDV2Adapter is Script {
    Addressbook addressbook = new Addressbook();
    error AssetIndexNotFound();

    function run(
        address multistrategy, 
        string memory name, 
        address curve_liquidity_pool, 
        uint256 slippage_limit_basis_points,
        address[] memory rewards
    ) public {

        require(multistrategy != address(0), "Multistrategy cannot be zero address");
        require(slippage_limit_basis_points < 100, "Slippage limit too high");

        address asset = IERC4626(multistrategy).asset();
        address manager = addressbook.getManager(block.chainid);
        address guardian = addressbook.getGuardian(block.chainid);
        address stake_dao_vault = getStakeDaoVault(curve_liquidity_pool);
        uint256 assetIndex = findAssetIndex(curve_liquidity_pool, asset);

        require(IERC4626(stake_dao_vault).asset() == curve_liquidity_pool, "Stake DAO Vault mismatch");

        StrategyAdapterHarvestable.HarvestAddresses memory harvestAddresses = StrategyAdapterHarvestable.HarvestAddresses({
            swapper: addressbook.getGoatSwapper(block.chainid),
            wrappedGas: addressbook.getWrappedGas(block.chainid)
        });

        CurveStableNgSDV2Adapter.CurveSNGSDV2Data memory curveData = CurveStableNgSDV2Adapter.CurveSNGSDV2Data({
            curveLiquidityPool: curve_liquidity_pool,
            sdVault: stake_dao_vault,
            curveSlippageUtility: addressbook.getUtilities(block.chainid, keccak256("CURVE_STABLENG_SLIPPAGE_UTILITY")),
            assetIndex: assetIndex
        });

        vm.startBroadcast();

        CurveStableNgSDV2Adapter adapter = new CurveStableNgSDV2Adapter(multistrategy, asset, harvestAddresses, curveData, name, "CRV-SDV2-LP");

        adapter.setSlippageLimit(slippage_limit_basis_points);                        // 0.05% Slippage permitted
        adapter.setCurveSlippageLimit(slippage_limit_basis_points * 0.0001 ether);    // 0.05% Slippage permitted
        adapter.setWithdrawBufferPPM(2);                                              // 2 parts per million buffer on withdraws
        for(uint i = 0; i < rewards.length; ++i) {
            adapter.addReward(rewards[i]);
        }

        adapter.enableGuardian(guardian);
        adapter.transferOwnership(manager);

        vm.stopBroadcast();
    }

    function getGaugeFactory(uint256 chainId) public pure returns (address) {
        if (chainId == 42161) return 0xabC000d88f23Bb45525E447528DBF656A9D55bf5; // Arbitrum
        revert("Unsupported network");
    }

    function getStakeDAOProtocolController(uint256 chainId) public pure returns (address) {
        if (chainId == 42161) return 0x2d8BcE1FaE00a959354aCD9eBf9174337A64d4fb; // Arbitrum
        revert("Unsupported network");
    }

    function getStakeDaoVault(address _curveLP) public view returns (address) {
        address gauge_factory = getGaugeFactory(block.chainid);
        address gauge = ICurveGaugeFactory(gauge_factory).get_gauge_from_lp_token(_curveLP);
        address stake_dao_protocol_controller = getStakeDAOProtocolController(block.chainid);
        return IProtocolController(stake_dao_protocol_controller).gauge(gauge).vault;
    }

    function findAssetIndex(address lp, address asset) private view returns (uint256) {
        uint256 nCoins = ICurveLiquidityPool(lp).N_COINS();
        for(uint256 i = 0; i < nCoins; ++i) {
            if(ICurveLiquidityPool(lp).coins(i) == asset) return i;
        }

        revert AssetIndexNotFound();
    }
}