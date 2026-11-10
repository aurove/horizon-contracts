// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {IVault} from "./interfaces/IVault.sol";
import {IAuroveId20} from "./vendor/aurove/interfaces/IAuroveId20.sol";
import {IId20Gauge} from "./vendor/aurove/interfaces/IId20Gauge.sol";
import {IId20RewardsSink} from "./vendor/aurove/interfaces/IId20RewardsSink.sol";

/// @dev Mezo testnet Id20 gauges still expose legacy `accountMetadata` (earned) instead of
///      `accountState` (claimableReward). Used only as a view fallback in {Vault.claimableRewards}.
interface ILegacyId20Gauge {
    struct AccountMetadata {
        bool isActive;
        uint256 weight;
        uint256 debt;
        uint256 credit;
        uint256 lent;
        uint256 accruedReward;
        uint256 earned;
    }

    function accountMetadata(address account)
        external
        view
        returns (AccountMetadata memory metadata);
}

/// @title Vault - ERC-4626 vault over one Id20 with permissionless gauge compounding
/// @notice Shares appreciate when attributable Id20Gauge rewards are claimed into the vault balance.
/// @dev Unclaimed gauge rewards are excluded from `totalAssets`. Constructor self-activates on the
///      Id20 gauge via an external `activate()` call so the gauge sees this vault as `msg.sender`.
contract Vault is ERC4626, ReentrancyGuard, IVault {
    /// @notice Id20 gauge that distributes attributable yield for this vault's underlying asset.
    IId20Gauge public immutable override gauge;

    /// @param asset_ Id20 ERC-20 underlying (must expose AuroveId20.rewardSink → Id20Gauge).
    /// @param name_ ERC-20 name for vault shares.
    /// @param symbol_ ERC-20 symbol for vault shares.
    constructor(IERC20 asset_, string memory name_, string memory symbol_)
        ERC20(name_, symbol_)
        ERC4626(asset_)
    {
        IId20RewardsSink sink = IAuroveId20(address(asset_)).rewardSink();
        if (address(sink) == address(0)) revert InvalidId20Asset(address(asset_));

        gauge = IId20Gauge(address(sink));
        // External call: gauge observes msg.sender == address(this), not the factory/deployer.
        gauge.activate();
    }

    /// @inheritdoc ERC4626
    /// @dev Only Id20 held by this vault. Unclaimed Id20Gauge rewards are not assets.
    function totalAssets() public view override(ERC4626, IERC4626) returns (uint256) {
        return IERC20(asset()).balanceOf(address(this));
    }

    /// @inheritdoc IVault
    /// @dev Prefer `accountState.claimableReward` (mainnet / current ABI); fall back to legacy
    ///      `accountMetadata.earned` when `accountState` is missing or reverts (Mezo testnet).
    ///      Soft-returns 0 if both views fail so {harvestAndCompound} stays tolerant (compound=0)
    ///      instead of reverting the whole call on a transient gauge view failure.
    function claimableRewards() public view returns (uint256) {
        try gauge.accountState(address(this)) returns (IId20Gauge.AccountState memory state) {
            return state.claimableReward;
        } catch {
            try ILegacyId20Gauge(address(gauge)).accountMetadata(address(this)) returns (
                ILegacyId20Gauge.AccountMetadata memory meta
            ) {
                return meta.earned;
            } catch {
                return 0;
            }
        }
    }

    /// @inheritdoc IVault
    function previewCompound() external view returns (uint256) {
        return claimableRewards();
    }

    /// @inheritdoc IVault
    function compound() external nonReentrant returns (uint256 compounded) {
        compounded = _compound();
    }

    /// @inheritdoc IVault
    function harvestAndCompound()
        external
        nonReentrant
        returns (uint256 harvested, uint256 compounded)
    {
        try IAuroveId20(asset()).claimRewards() returns (uint256 h) {
            harvested = h;
        } catch {
            harvested = 0;
        }

        uint256 claimable = claimableRewards();
        if (claimable == 0) {
            return (harvested, 0);
        }

        compounded = gauge.claim(address(this));
        emit Compounded(msg.sender, compounded);
    }

    /// @inheritdoc ERC4626
    function deposit(uint256 assets, address receiver)
        public
        override(ERC4626, IERC4626)
        nonReentrant
        returns (uint256)
    {
        return super.deposit(assets, receiver);
    }

    /// @inheritdoc ERC4626
    function mint(uint256 shares, address receiver)
        public
        override(ERC4626, IERC4626)
        nonReentrant
        returns (uint256)
    {
        return super.mint(shares, receiver);
    }

    /// @inheritdoc ERC4626
    function withdraw(uint256 assets, address receiver, address owner)
        public
        override(ERC4626, IERC4626)
        nonReentrant
        returns (uint256)
    {
        return super.withdraw(assets, receiver, owner);
    }

    /// @inheritdoc ERC4626
    function redeem(uint256 shares, address receiver, address owner)
        public
        override(ERC4626, IERC4626)
        nonReentrant
        returns (uint256)
    {
        return super.redeem(shares, receiver, owner);
    }

    function _compound() private returns (uint256 compounded) {
        uint256 claimable = claimableRewards();
        if (claimable == 0) revert NoRewardsToCompound();

        compounded = gauge.claim(address(this));
        emit Compounded(msg.sender, compounded);
    }
}
