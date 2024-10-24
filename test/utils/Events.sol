// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

abstract contract Events {
    /*//////////////////////////////////////////////////////////////////////////
                                      GENERICS
    //////////////////////////////////////////////////////////////////////////*/

    event SetKeeper(address indexed keeper);

    /*//////////////////////////////////////////////////////////////////////////
                                    MULTISTRATEGY
    //////////////////////////////////////////////////////////////////////////*/

    event ManagerSet(address indexed manager);

    event GuardianEnabled(address indexed guardian);

    event GuardianRevoked(address indexed guardian);

    event ProtocolFeeRecipientSet(address indexed protocolFeeRecipient);

    event PerformanceFeeSet(uint256 performanceFee);

    event DepositLimitSet(uint256 depositLimit);

    event WithdrawOrderSet();

    event StrategyDebtRatioSet(address indexed strategy, uint256 debtRatio);

    event StrategyMinDebtDeltaSet(address indexed strategy, uint256 minDebtDelta);

    event StrategyMaxDebtDeltaSet(address indexed strategy, uint256 maxDebtDelta);

    event StrategyAdded(address indexed strategy);

    event StrategyRetired(address indexed strategy);

    event StrategyRemoved(address indexed strategy);

    event Deposit(address indexed sender, address indexed owner, uint256 assets, uint256 shares);

    event Withdraw(
        address indexed sender, address indexed receiver, address indexed owner, uint256 assets, uint256 shares
    );

    event CreditRequested(address indexed strategy, uint256 amount);

    event StrategyReported(address indexed strategy, uint256 debtRepaid, uint256 gain, uint256 loss);

    /*//////////////////////////////////////////////////////////////////////////
                                    STRATEGY_ADAPTER
    //////////////////////////////////////////////////////////////////////////*/
    
    event SlippageLimitSet(uint256 slippageLimit);

    /*//////////////////////////////////////////////////////////////////////////
                                        PAUSABLE
    //////////////////////////////////////////////////////////////////////////*/

    event Paused(address account);
    
    event Unpaused(address account);
}