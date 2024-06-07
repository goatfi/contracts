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

    event Deposit(uint256 amount, address indexed recipient);

    event Withdraw(uint256 amount);

    event CreditRequested(address indexed strategy, uint256 amount);

    event StrategyReported(address indexed strategy, uint256 debtRepaid, uint256 gain, uint256 loss);

    /*//////////////////////////////////////////////////////////////////////////
                                        PAUSABLE
    //////////////////////////////////////////////////////////////////////////*/

    event Paused(address account);
    
    event Unpaused(address account);
}