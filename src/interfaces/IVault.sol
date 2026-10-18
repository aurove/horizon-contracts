// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";

import {IId20Gauge} from "../vendor/aurove/interfaces/IId20Gauge.sol";

/// @title IVault - ERC-4626 vault over one Id20 asset with gauge compounding
interface IVault is IERC4626 {
    error InvalidId20Asset(address asset);
    error NoRewardsToCompound();

    event Compounded(address indexed caller, uint256 amount);

    function gauge() external view returns (IId20Gauge);

    function claimableRewards() external view returns (uint256);

    function previewCompound() external view returns (uint256);

    function compound() external returns (uint256 compounded);

    function harvestAndCompound() external returns (uint256 harvested, uint256 compounded);
}
