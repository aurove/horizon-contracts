// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {Vault} from "../src/Vault.sol";
import {MockId20} from "./mocks/MockId20.sol";
import {MockId20Gauge} from "./mocks/MockId20Gauge.sol";

/// @notice Dual-ABI claimableRewards: legacy `accountMetadata.earned` when `accountState` reverts.
contract VaultLegacyClaimableTest is Test {
    address internal constant FAKE_ERC1155 = address(0x1155);

    MockId20 internal id20;
    MockId20Gauge internal gauge;
    Vault internal vault;
    address internal alice = makeAddr("alice");

    function setUp() public {
        id20 = new MockId20("avBTCm", "avBTCm", FAKE_ERC1155, 0x010004);
        gauge = id20.mockGauge();
        vault = new Vault(IERC20(address(id20)), "avBTC Vault", "avBTCv");

        id20.mint(alice, 100e18);
        vm.startPrank(alice);
        id20.approve(address(vault), type(uint256).max);
        vault.deposit(100e18, alice);
        vm.stopPrank();
    }

    function test_claimableRewards_fallsBackToAccountMetadataEarned() public {
        uint256 amount = 25e18;
        id20.mint(address(gauge), amount);
        gauge.fundClaimable(address(vault), amount);

        assertEq(vault.claimableRewards(), amount, "accountState path");

        gauge.setRevertAccountState(true);
        assertEq(vault.claimableRewards(), amount, "legacy accountMetadata.earned path");
        assertEq(vault.previewCompound(), amount);
    }

    function test_compound_worksWhenOnlyLegacyMetadataReadable() public {
        uint256 amount = 11e18;
        id20.mint(address(gauge), amount);
        gauge.fundClaimable(address(vault), amount);
        gauge.setRevertAccountState(true);

        uint256 assetsBefore = vault.totalAssets();
        uint256 compounded = vault.compound();

        assertEq(compounded, amount);
        assertEq(vault.totalAssets(), assetsBefore + amount);
        assertEq(vault.claimableRewards(), 0);
    }

    function test_claimableRewards_prefersAccountStateWhenAvailable() public {
        uint256 amount = 7e18;
        id20.mint(address(gauge), amount);
        gauge.fundClaimable(address(vault), amount);

        assertFalse(gauge.revertAccountState());
        assertEq(vault.claimableRewards(), amount);
        assertEq(vault.previewCompound(), amount);
    }
}
