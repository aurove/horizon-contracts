// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/// @notice Minimal vendor copy of packages/id20 IId20Gauge (activation + claim surface).
/// @dev Does not declare `id20()` — that lives on {IId20RewardsSink}.
interface IId20Gauge {
    struct AccountState {
        bool isActivated;
        uint256 settledUnits;
        uint256 rewardWeight;
        uint256 debtWeight;
        uint256 unsettledCredit;
        uint256 lentWeight;
        uint256 claimableReward;
    }

    function accountState(address account) external view returns (AccountState memory state);

    function activate() external;

    function claim(address receiver) external returns (uint256 claimed);
}
