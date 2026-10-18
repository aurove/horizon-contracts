// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

import {Vault} from "./Vault.sol";
import {IVaultFactory} from "./interfaces/IVaultFactory.sol";
import {IAuroveId20} from "./vendor/aurove/interfaces/IAuroveId20.sol";
import {IId20} from "./vendor/aurove/interfaces/IId20.sol";
import {IId20RewardsSink} from "./vendor/aurove/interfaces/IId20RewardsSink.sol";

/// @title VaultFactory - Permissionless one-vault-per-Id20 registry
/// @notice `createVault` reverts on duplicates; `getOrCreateVault` is the idempotent path and ignores
///         `name`/`symbol` when a vault already exists.
contract VaultFactory is IVaultFactory {
    mapping(address asset => address vault) private _vaultOfAsset;
    mapping(address account => bool) private _isVault;
    address[] private _allVaults;

    /// @inheritdoc IVaultFactory
    function getVault(address asset) external view returns (address vault) {
        return _vaultOfAsset[asset];
    }

    /// @inheritdoc IVaultFactory
    function allVaultsLength() external view returns (uint256) {
        return _allVaults.length;
    }

    /// @inheritdoc IVaultFactory
    function allVaults(uint256 index) external view returns (address vault) {
        return _allVaults[index];
    }

    /// @inheritdoc IVaultFactory
    function isVault(address account) external view returns (bool) {
        return _isVault[account];
    }

    /// @inheritdoc IVaultFactory
    function createVault(address asset, string calldata name, string calldata symbol)
        external
        returns (address vault)
    {
        return _createVault(asset, name, symbol);
    }

    /// @inheritdoc IVaultFactory
    function getOrCreateVault(address asset, string calldata name, string calldata symbol)
        external
        returns (address vault)
    {
        vault = _vaultOfAsset[asset];
        if (vault != address(0)) {
            // Existing vault: name/symbol are ignored (share metadata is immutable).
            return vault;
        }
        return _createVault(asset, name, symbol);
    }

    function _createVault(address asset, string memory name, string memory symbol)
        private
        returns (address vault)
    {
        if (asset == address(0)) revert ZeroAddress();

        address existing = _vaultOfAsset[asset];
        if (existing != address(0)) revert VaultAlreadyExists(asset, existing);

        address gauge = _validateId20(asset);
        vault = address(new Vault(IERC20(asset), name, symbol));

        _vaultOfAsset[asset] = vault;
        _isVault[vault] = true;
        _allVaults.push(vault);

        emit VaultCreated(asset, vault, gauge, name, symbol);
    }

    /// @dev Best-effort ABI validation — not a whitelist.
    function _validateId20(address asset) private view returns (address gauge) {
        IId20RewardsSink sink = IAuroveId20(asset).rewardSink();
        gauge = address(sink);
        if (gauge == address(0)) revert InvalidId20Asset(asset);

        if (address(sink.id20()) != asset) revert InvalidId20Asset(asset);

        IERC1155 underlying = IId20(asset).asset();
        if (address(underlying) == address(0)) revert InvalidId20Asset(asset);
        if (IId20(asset).id() == 0) revert InvalidId20Asset(asset);
    }
}
