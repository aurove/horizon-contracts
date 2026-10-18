// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {Vault} from "../src/Vault.sol";
import {IVault} from "../src/interfaces/IVault.sol";
import {IId20Gauge} from "../src/vendor/aurove/interfaces/IId20Gauge.sol";
import {MockId20} from "./mocks/MockId20.sol";
import {MockId20Gauge} from "./mocks/MockId20Gauge.sol";

contract VaultTest is Test {
    address internal constant DEAD = 0x000000000000000000000000000000000000dEaD;
    address internal constant FAKE_ERC1155 = address(0x1155);

    MockId20 internal id20;
    MockId20Gauge internal gauge;
    Vault internal vault;

    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");

    function setUp() public {
        id20 = new MockId20("avBTCm", "avBTCm", FAKE_ERC1155, 0x010004);
        gauge = id20.mockGauge();
        vault = new Vault(IERC20(address(id20)), "avBTC Vault", "avBTCv");
    }

    function test_constructor_activatesVaultNotDeployer() public view {
        IId20Gauge.AccountState memory vaultState = gauge.accountState(address(vault));
        IId20Gauge.AccountState memory deployerState = gauge.accountState(address(this));

        assertTrue(vaultState.isActivated, "vault must be activated");
        assertFalse(deployerState.isActivated, "deployer must not be activated");
        assertEq(address(vault.gauge()), address(gauge));
        assertEq(vault.asset(), address(id20));
    }

    function test_deposit_mint_withdraw_redeem() public {
        uint256 assets = 100e18;
        id20.mint(alice, assets);

        vm.startPrank(alice);
        id20.approve(address(vault), assets);
        uint256 shares = vault.deposit(assets, alice);
        vm.stopPrank();

        assertEq(shares, assets); // 1:1 with empty vault + virtual shares offset 0
        assertEq(vault.balanceOf(alice), shares);
        assertEq(vault.totalAssets(), assets);
        assertEq(id20.balanceOf(address(vault)), assets);

        vm.prank(alice);
        uint256 withdrawn = vault.redeem(shares / 2, bob, alice);

        assertEq(withdrawn, assets / 2);
        assertEq(id20.balanceOf(bob), assets / 2);
        assertEq(vault.totalAssets(), assets / 2);
    }

    function test_mint_and_withdraw() public {
        uint256 shares = 50e18;
        id20.mint(alice, 100e18);

        vm.startPrank(alice);
        id20.approve(address(vault), type(uint256).max);
        uint256 assetsIn = vault.mint(shares, alice);
        uint256 sharesOut = vault.withdraw(assetsIn / 2, alice, alice);
        vm.stopPrank();

        assertEq(assetsIn, shares);
        assertGt(sharesOut, 0);
        assertEq(id20.balanceOf(alice), 100e18 - assetsIn + assetsIn / 2);
    }

    function test_totalAssets_excludesUnclaimedRewards() public {
        id20.mint(alice, 100e18);
        vm.startPrank(alice);
        id20.approve(address(vault), 100e18);
        vault.deposit(100e18, alice);
        vm.stopPrank();

        id20.mint(address(gauge), 25e18);
        gauge.fundClaimable(address(vault), 25e18);

        assertEq(vault.claimableRewards(), 25e18);
        assertEq(vault.previewCompound(), 25e18);
        assertEq(vault.totalAssets(), 100e18, "unclaimed must not count");
    }

    function test_donation_increasesTotalAssetsAndSharePrice() public {
        id20.mint(alice, 100e18);
        vm.startPrank(alice);
        id20.approve(address(vault), 100e18);
        vault.deposit(100e18, alice);
        vm.stopPrank();

        uint256 priceBefore = vault.convertToAssets(1e18);
        id20.mint(address(vault), 50e18); // direct donation
        uint256 priceAfter = vault.convertToAssets(1e18);

        assertEq(vault.totalAssets(), 150e18);
        assertGt(priceAfter, priceBefore);
    }

    function test_withdraw_afterDonation() public {
        id20.mint(alice, 100e18);
        vm.startPrank(alice);
        id20.approve(address(vault), 100e18);
        vault.deposit(100e18, alice);
        vm.stopPrank();

        id20.mint(address(vault), 20e18);

        uint256 shares = vault.balanceOf(alice);
        vm.prank(alice);
        vault.redeem(shares, alice, alice);

        assertEq(vault.totalSupply(), 0);
        // OZ virtual shares can leave ≤1 wei asset dust after a full redeem with donations.
        assertApproxEqAbs(id20.balanceOf(alice), 120e18, 1);
        assertLe(vault.totalAssets(), 1);
    }

    function test_deadShareSeed_dilutesSupply() public {
        id20.mint(address(this), 1e12);
        id20.approve(address(vault), 1e12);
        uint256 seedShares = vault.deposit(1e12, address(this));
        vault.transfer(DEAD, seedShares);

        assertEq(vault.balanceOf(DEAD), seedShares);
        assertEq(vault.totalSupply(), seedShares);
        assertGt(seedShares, 0);
    }
}
