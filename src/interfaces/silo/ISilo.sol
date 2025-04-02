// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin-4/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin-4/contracts/token/ERC20/utils/SafeERC20.sol";

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