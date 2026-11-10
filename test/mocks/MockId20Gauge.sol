// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IId20Gauge} from "../../src/vendor/aurove/interfaces/IId20Gauge.sol";
import {IId20RewardsSink} from "../../src/vendor/aurove/interfaces/IId20RewardsSink.sol";

/// @dev Simplified gauge: activation tracking + settable claimable balances for vault tests.
///      Optionally reverts `accountState` so Vault's legacy `accountMetadata` fallback can be exercised.
contract MockId20Gauge is IId20Gauge, IId20RewardsSink {
    using SafeERC20 for IERC20;

    IERC20 public immutable override id20;

    mapping(address => bool) public activated;
    mapping(address => uint256) public claimable;
    /// @dev Distinct from `claimable`/`earned` so tests can prove Vault maps earned -> claimableReward
    ///      (same as scripts/lib/id20-gauge-compat.ts `mapAccountMetadataToState`).
    mapping(address => uint256) public accruedReward;
    uint256 public rewardReserve;
    /// @dev When true, `accountState` reverts so callers exercise the legacy metadata path.
    bool public revertAccountState;
    /// @dev When true, `accountMetadata` reverts (both-views-fail soft-zero path).
    bool public revertAccountMetadata;

    error AlreadyActive(address account);
    error NotInitialized(address account);
    error NoRewards();
    error ZeroReceiver();
    error AccountStateUnavailable();
    error AccountMetadataUnavailable();

    constructor(IERC20 id20_) {
        id20 = id20_;
    }

    function setRevertAccountState(bool value) external {
        revertAccountState = value;
    }

    function setRevertAccountMetadata(bool value) external {
        revertAccountMetadata = value;
    }

    function setAccruedReward(address account, uint256 amount) external {
        accruedReward[account] = amount;
    }

    function accountState(address account) external view returns (AccountState memory state) {
        if (revertAccountState) revert AccountStateUnavailable();
        state.isActivated = activated[account];
        state.claimableReward = claimable[account];
    }

    /// @dev Legacy testnet shape; Vault / id20-gauge-compat map `earned` -> claimableReward (not accruedReward).
    function accountMetadata(address account)
        external
        view
        returns (
            bool isActive,
            uint256, /* weight */
            uint256, /* debt */
            uint256, /* credit */
            uint256, /* lent */
            uint256 accrued,
            uint256 earned
        )
    {
        if (revertAccountMetadata) revert AccountMetadataUnavailable();
        return (activated[account], 0, 0, 0, 0, accruedReward[account], claimable[account]);
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
