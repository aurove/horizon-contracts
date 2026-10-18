// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {Vault} from "../src/Vault.sol";
import {IVault} from "../src/interfaces/IVault.sol";
import {MockId20} from "./mocks/MockId20.sol";
import {MockId20Gauge} from "./mocks/MockId20Gauge.sol";

contract VaultCompoundTest is Test {
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

    function test_compound_increasesAssetsPerShare() public {
        uint256 priceBefore = vault.convertToAssets(1e18);
        uint256 supplyBefore = vault.totalSupply();

        _fundVaultClaimable(25e18);

        uint256 compounded = vault.compound();
        assertEq(compounded, 25e18);
        assertEq(vault.totalAssets(), 125e18);
        assertEq(vault.totalSupply(), supplyBefore, "shares must not dilute");
        assertGt(vault.convertToAssets(1e18), priceBefore);
        assertEq(vault.claimableRewards(), 0);
    }

    function test_compound_revertsWhenZero() public {
        vm.expectRevert(IVault.NoRewardsToCompound.selector);
        vault.compound();
    }

    function test_harvestAndCompound_returnsZeroCompoundWhenNoClaimable() public {
        id20.setNextHarvestAmount(10e18);
        // Harvest mints to gauge but does not credit vault claimable in this mock unless funded.
        (uint256 harvested, uint256 compounded) = vault.harvestAndCompound();
        assertEq(harvested, 10e18);
        assertEq(compounded, 0);
    }

    function test_harvestAndCompound_tolerantOfHarvestFailure() public {
        id20.setHarvestReverts(true);
        _fundVaultClaimable(5e18);

        (uint256 harvested, uint256 compounded) = vault.harvestAndCompound();
        assertEq(harvested, 0);
        assertEq(compounded, 5e18);
        assertEq(vault.totalAssets(), 105e18);
    }

    function test_harvestAndCompound_compoundsWhenClaimable() public {
        id20.setNextHarvestAmount(7e18);
        _fundVaultClaimable(3e18);

        (uint256 harvested, uint256 compounded) = vault.harvestAndCompound();
        assertEq(harvested, 7e18);
        assertEq(compounded, 3e18);
        assertEq(vault.totalAssets(), 103e18);
    }

    function test_permissionlessCompound() public {
        _fundVaultClaimable(1e18);
        vm.prank(makeAddr("keeper"));
        uint256 compounded = vault.compound();
        assertEq(compounded, 1e18);
    }

    function _fundVaultClaimable(uint256 amount) internal {
        id20.mint(address(gauge), amount);
        gauge.fundClaimable(address(vault), amount);
    }
}
