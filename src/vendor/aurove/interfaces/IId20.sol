// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

/// @notice Minimal vendor copy of packages/id20 IId20 (factory validation surface).
interface IId20 {
    function asset() external view returns (IERC1155);

    function id() external view returns (uint256);
}
