// SPDX-License-Identifier: MIT
pragma solidity^0.8.20;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { GoatVault } from "src/infra/vault/GoatVault.sol";
import { IGoatVaultFactory } from "interfaces/infra/IGoatVaultFactory.sol";
import { IStrategy } from "interfaces/infra/IStrategy.sol";
import { StratFeeManagerInitializable } from "src/infra/strategies/common/StratFeeManagerInitializable.sol";
import { StrategyCurveConvexL2 } from "src/infra/strategies/curve/StrategyCurveConvexL2.sol";
import { CurveLendAdapter } from "src/infra/multistrategy/adapters/CurveLendAdapter.sol";
import { AssetsArbitrum } from "@addressbook/AssetsArbitrum.sol";
import { ProtocolArbitrum } from "@addressbook/ProtocolArbitrum.sol";

interface ICurveLend {
    function deposit(uint256 assets) external;
}

contract DeployCurveLendAdapter is Script {
    /////////////////////////////////////////////////////////
    //                    VAULT CONFIG                     //
    /////////////////////////////////////////////////////////
    /*string name = "Goat CurveLend CRV-crvUSD";                                //FIXME:
    string symbol = "gCLCRV-crvUSD";                                     //FIXME:
    uint256 stratApprovalDelay = 21600;
    uint256 pid = 42069;
    address native = AssetsArbitrum.WETH;
    address want = 0xeEaF2ccB73A01deb38Eca2947d963D64CfDe6A32; // cvcrvusd token //FIXME:
    address depositToken = AssetsArbitrum.CRVUSD;
    address rewardPool = ProtocolArbitrum.GOAT_REWARD_POOL;
    address gauge = 0xb999E6177CAc62d40f2FDD1fE396DaD411F40499; // FIXME:

    uint256 constant INITIAL_DEPOSIT = 1 ether;

    StratFeeManagerInitializable.CommonAddresses commonAddresses;

    address[] rewards = [AssetsArbitrum.CRV, AssetsArbitrum.CRVUSD, AssetsArbitrum.ARB];

    address unirouter = ProtocolArbitrum.GOAT_SWAPPER;
    address keeper = ProtocolArbitrum.TREASURY;
    address strategist = 0xbd297B4f9991FD23f54e14111EE6190C4Fb9F7e1;
    address protocolFeeRecipient = ProtocolArbitrum.GOAT_FEE_BATCH;
    address feeConfig = ProtocolArbitrum.FEE_CONFIG;
    address timelock = ProtocolArbitrum.TIMELOCK;*/

    /////////////////////////////////////////////////////////
    //                   ADAPTER CONFIG                    //
    /////////////////////////////////////////////////////////
    address constant MULTISTRATEGY = 0xA7781F1D982Eb9000BC1733E29Ff5ba2824cDBE5;
    address constant ASSET = AssetsArbitrum.CRVUSD;
    address constant GUARDIAN = 0xbd297B4f9991FD23f54e14111EE6190C4Fb9F7e1;
    address constant TESTING_CUSTODIAN = 0x75cb5d555933fe86E0ac8975A623aCb5CEC13E28;
    string constant NAME = "Curve Lend WBTC non-Lev";                                  //FIXME:
    string constant ID = "CRVLEND";

    address vault = 0x87b1f2852437788b8098F3Ad903d32Cde34C7DEd;
    address want = 0x60D38b12d22BF423F28082bf396ff8F28cC506B1;

    function run() public {
        //IGoatVaultFactory vaultFactory = IGoatVaultFactory(ProtocolArbitrum.GOAT_VAULT_FACTORY);

        vm.startBroadcast();

        /*if(IERC20(ASSET).balanceOf(msg.sender) < INITIAL_DEPOSIT) {
            console.log("\u001b[1;31m NOT ENOUGH ASSETS FOR INITIAL DEPOSIT \u001b[0m");
            return;
        }

        /////////////////////////////////////////////////////////
        //                   VAULT DEPLOYMENT                  //
        /////////////////////////////////////////////////////////

        GoatVault vault = vaultFactory.cloneVault();
        StrategyCurveConvexL2 strategy = new StrategyCurveConvexL2();

        commonAddresses = StratFeeManagerInitializable.CommonAddresses(
            address(vault),
            unirouter,
            keeper,
            strategist,
            protocolFeeRecipient,
            feeConfig
            );

        vault.initialize(IStrategy(address(strategy)), name, symbol, stratApprovalDelay);
        strategy.initialize(native, want, gauge, pid, depositToken, rewards, commonAddresses);

        /////////////////////////////////////////////////////////
        //                    VAULT TESTING                    //
        /////////////////////////////////////////////////////////

        IERC20(ASSET).approve(want, INITIAL_DEPOSIT);
        ICurveLend(want).deposit(INITIAL_DEPOSIT);

        IERC20(want).approve(address(vault), IERC20(want).balanceOf(msg.sender));
        vault.depositAll();

        strategy.panic();
        strategy.unpause();
        strategy.harvest();

        vault.transferOwnership(timelock);
        strategy.transferOwnership(timelock);*/

        /////////////////////////////////////////////////////////
        //                 ADAPTER DEPLOYMENT                  //
        /////////////////////////////////////////////////////////

        CurveLendAdapter adapter = new CurveLendAdapter(MULTISTRATEGY, ASSET, want, address(vault), NAME, ID);
        adapter.enableGuardian(GUARDIAN);
        adapter.transferOwnership(TESTING_CUSTODIAN);

        vm.stopBroadcast();

        //console.log("Vault:", address(vault));
        //console.log("Strategy:", address(strategy));
        console.log("Curve Lend Adapter:", address(adapter));
    }
}