// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {Vault} from "../../src/Vault.sol";
import {MockId20} from "../mocks/MockId20.sol";
import {MockId20Gauge} from "../mocks/MockId20Gauge.sol";

contract VaultHandler is Test {
    Vault public vault;
    MockId20 public id20;
    MockId20Gauge public gauge;
    address[] public actors;

    constructor(Vault vault_, MockId20 id20_) {
        vault = vault_;
        id20 = id20_;
        gauge = id20_.mockGauge();
        actors.push(makeAddr("actor0"));
        actors.push(makeAddr("actor1"));
        actors.push(makeAddr("actor2"));
        for (uint256 i; i < actors.length; ++i) {
            id20.mint(actors[i], 1_000_000e18);
            vm.prank(actors[i]);
            id20.approve(address(vault), type(uint256).max);
        }
    }

    function deposit(uint256 actorSeed, uint256 amount) external {
        address actor = actors[actorSeed % actors.length];
        amount = bound(amount, 0, id20.balanceOf(actor));
        if (amount == 0) return;
        vm.prank(actor);
        vault.deposit(amount, actor);
    }

    function redeem(uint256 actorSeed, uint256 shares) external {
        address actor = actors[actorSeed % actors.length];
        uint256 bal = vault.balanceOf(actor);
        if (bal == 0) return;
        shares = bound(shares, 1, bal);
        vm.prank(actor);
        vault.redeem(shares, actor, actor);
    }

    function donate(uint256 amount) external {
        amount = bound(amount, 0, 1000e18);
        if (amount == 0) return;
        id20.mint(address(vault), amount);
    }

    function compound(uint256 amount) external {
        amount = bound(amount, 0, 100e18);
        if (amount == 0) return;
        id20.mint(address(gauge), amount);
        gauge.fundClaimable(address(vault), amount);
        vault.compound();
    }
}

contract VaultInvariantTest is StdInvariant, Test {
    address internal constant FAKE_ERC1155 = address(0x1155);

    Vault internal vault;
    MockId20 internal id20;
    VaultHandler internal handler;

    function setUp() public {
        id20 = new MockId20("avBTCm", "avBTCm", FAKE_ERC1155, 0x010004);
        vault = new Vault(IERC20(address(id20)), "avBTC Vault", "avBTCv");
        handler = new VaultHandler(vault, id20);
        targetContract(address(handler));
    }

    function invariant_totalAssetsEqBalance() public view {
        assertEq(vault.totalAssets(), id20.balanceOf(address(vault)));
    }

    function invariant_convertRoundTrip() public view {
        uint256 supply = vault.totalSupply();
        if (supply == 0) return;
        uint256 assets = vault.convertToAssets(supply);
        // Allow 1 wei rounding slack on full-supply conversion.
        assertLe(assets, vault.totalAssets());
    }

    function invariant_solvency() public view {
        if (vault.totalSupply() == 0) return;
        assertGe(vault.totalAssets() + 1, vault.convertToAssets(vault.totalSupply()));
    }
}
