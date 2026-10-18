// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @notice Minimal vendor copy of packages/id20 IId20RewardsSink (id20 back-pointer + hooks).
interface IId20RewardsSink {
    function id20() external view returns (IERC20);

    function notifyReward() external returns (uint256 amount);

    function beforeId20Transfer(address from, address to, uint256 amount) external;
}
