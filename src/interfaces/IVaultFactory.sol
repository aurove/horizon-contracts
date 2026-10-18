// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/// @title IVaultFactory - Deploy and register at most one vault per Id20 asset
interface IVaultFactory {
    error ZeroAddress();
    error VaultAlreadyExists(address asset, address vault);
    error InvalidId20Asset(address asset);

    event VaultCreated(
        address indexed asset,
        address indexed vault,
        address indexed gauge,
        string name,
        string symbol
    );

    function getVault(address asset) external view returns (address vault);

    function allVaultsLength() external view returns (uint256);

    function allVaults(uint256 index) external view returns (address vault);

    function isVault(address account) external view returns (bool);

    function createVault(address asset, string calldata name, string calldata symbol)
        external
        returns (address vault);

    function getOrCreateVault(address asset, string calldata name, string calldata symbol)
        external
        returns (address vault);
}
