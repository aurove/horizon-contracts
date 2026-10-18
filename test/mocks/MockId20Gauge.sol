// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IId20Gauge} from "../../src/vendor/aurove/interfaces/IId20Gauge.sol";
import {IId20RewardsSink} from "../../src/vendor/aurove/interfaces/IId20RewardsSink.sol";

/// @dev Simplified gauge: activation tracking + settable claimable balances for vault tests.
contract MockId20Gauge is IId20Gauge, IId20RewardsSink {
    using SafeERC20 for IERC20;

    IERC20 public immutable override id20;

    mapping(address => bool) public activated;
    mapping(address => uint256) public claimable;
    uint256 public rewardReserve;

    error AlreadyActive(address account);
    error NotInitialized(address account);
    error NoRewards();
    error ZeroReceiver();

    constructor(IERC20 id20_) {
        id20 = id20_;
    }

    function accountState(address account) external view returns (AccountState memory state) {
        state.isActivated = activated[account];
        state.claimableReward = claimable[account];
    }

    function activate() external {
        address account = msg.sender;
        if (activated[account]) revert AlreadyActive(account);
        activated[account] = true;
    }

    function setClaimable(address account, uint256 amount) external {
        claimable[account] = amount;
    }

    /// @dev Funds the gauge with Id20 and credits `account` claimable (caller must transfer tokens first
    ///      or use notifyReward after minting to this gauge).
    function fundClaimable(address account, uint256 amount) external {
        claimable[account] += amount;
        rewardReserve += amount;
    }

    function notifyReward(uint256 amount) external {
        rewardReserve += amount;
    }

    function notifyReward() external returns (uint256 amount) {
        uint256 balance = id20.balanceOf(address(this));
        if (balance <= rewardReserve) revert NoRewards();
        amount = balance - rewardReserve;
        rewardReserve = balance;
    }

    function beforeId20Transfer(address, address, uint256) external {}

    function claim(address receiver) external returns (uint256 claimed) {
        if (receiver == address(0)) revert ZeroReceiver();
        address account = msg.sender;
        if (!activated[account]) revert NotInitialized(account);

        claimed = claimable[account];
        if (claimed == 0) revert NoRewards();

        claimable[account] = 0;
        rewardReserve -= claimed;
        id20.safeTransfer(receiver, claimed);
    }
}
