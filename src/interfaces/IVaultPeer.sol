// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title IVaultPeer
/// @notice ERC-20 peer token interface required by Wormhole NTT in burning mode.
interface IVaultPeer is IERC20 {
    error CallerNotMinter(address caller);
    error InvalidMinterZeroAddress();
    error MinterAlreadySet();

    event NewMinter(address previousMinter, address newMinter);

    /// @notice Set the NTT manager authorized to mint and burn peer tokens.
    function setMinter(address newMinter) external;

    /// @notice Mint peer tokens to a recipient after a verified inbound NTT transfer.
    function mint(address account, uint256 amount) external;

    /// @notice Burn tokens held by the NTT manager for an outbound NTT transfer.
    function burn(uint256 amount) external;
}
