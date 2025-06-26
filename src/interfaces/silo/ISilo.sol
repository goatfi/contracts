// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

struct AssetStorage {
        address collateralToken;
        address collateralOnlyToken;
        address debtToken;
        uint256 totalDeposits;
        uint256 collateralOnlyDeposits;
        uint256 totalBorrowAmount;
}

interface ISilo {
    function deposit(address asset, uint amount, bool collateralOnly) external;

    function withdraw(address asset, uint amount, bool collateralOnly) external;

    function balanceOf(address user) external view returns (uint256);

    function assetStorage(address asset) external view returns(AssetStorage memory);
}

interface ISiloRepository {
    function getSilo(address asset) external returns (address);
}

interface ISiloCollateralToken {
    function asset() external view returns (address);
}

interface ISiloLens {
    function balanceOfUnderlying(
        uint256 _assetTotalDeposits,
        address _shareToken,
        address _user
    ) external view returns (uint256);

    function totalDepositsWithInterest(
        address _silo,
        address _asset
    ) external view returns (uint256 _totalDeposits);

    function getDepositAmount(
        address _silo, 
        address _asset, 
        address _user, 
        uint256 _timestamp
        ) external view returns (uint256 _totalUserDeposits);
}

interface ISiloRewards {
    function claimRewardsToSelf(
        address[] memory assets,
        uint256 amount
    ) external;
}

interface ISiloIncentivesController {
    function claimRewards(address to) external;
}

interface IxSilo {
    function redeemSilo(uint256 _xSiloAmountToBurn, uint256 _duration) external;
}