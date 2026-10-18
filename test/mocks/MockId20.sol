// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

import {IId20RewardsSink} from "../../src/vendor/aurove/interfaces/IId20RewardsSink.sol";
import {MockId20Gauge} from "./MockId20Gauge.sol";

/// @dev Mintable Id20 stand-in with a paired mock gauge for vault unit tests.
contract MockId20 is ERC20 {
    MockId20Gauge public immutable mockGauge;
    IERC1155 public immutable underlyingAsset;
    uint256 public immutable underlyingId;

    bool public harvestReverts;
    uint256 public nextHarvestAmount;

    constructor(string memory name_, string memory symbol_, address underlyingAsset_, uint256 id_)
        ERC20(name_, symbol_)
    {
        underlyingAsset = IERC1155(underlyingAsset_);
        underlyingId = id_;
        mockGauge = new MockId20Gauge(IERC20(address(this)));
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external {
        _burn(from, amount);
    }

    function rewardSink() external view returns (IId20RewardsSink) {
        return IId20RewardsSink(address(mockGauge));
    }

    function asset() external view returns (IERC1155) {
        return underlyingAsset;
    }

    function id() external view returns (uint256) {
        return underlyingId;
    }

    function setHarvestReverts(bool value) external {
        harvestReverts = value;
    }

    function setNextHarvestAmount(uint256 amount) external {
        nextHarvestAmount = amount;
    }

    /// @dev Mints `nextHarvestAmount` to the gauge and returns it (simulates upstream harvest notify).
    function claimRewards() external returns (uint256 claimed) {
        if (harvestReverts) revert("harvest failed");
        claimed = nextHarvestAmount;
        if (claimed == 0) revert("NoRewardsClaimed");
        nextHarvestAmount = 0;
        _mint(address(mockGauge), claimed);
        mockGauge.notifyReward(claimed);
    }
}
