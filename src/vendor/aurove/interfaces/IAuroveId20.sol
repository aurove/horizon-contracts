// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IId20} from "./IId20.sol";
import {IId20RewardsSink} from "./IId20RewardsSink.sol";

/// @notice Minimal vendor copy of packages/id20 IAuroveId20 (harvest + gauge resolution).
interface IAuroveId20 is IId20 {
    function rewardSink() external view returns (IId20RewardsSink);

    function claimRewards() external returns (uint256 claimed);
}
