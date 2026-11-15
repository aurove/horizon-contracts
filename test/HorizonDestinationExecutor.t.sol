// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {HorizonDestinationExecutor} from "../src/HorizonDestinationExecutor.sol";
import {MockSlipstreamSwapRouter} from "./mocks/MockSlipstreamSwapRouter.sol";

contract MockERC20 is ERC20 {
    constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_) {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract HorizonDestinationExecutorTest is Test {
    int24 internal constant TICK_SPACING = 200;

    HorizonDestinationExecutor internal executor;
    MockSlipstreamSwapRouter internal router;
    MockERC20 internal musd;
    MockERC20 internal peer;
    address internal npm;
    address internal user;

    function setUp() public {
        npm = makeAddr("npm");
        user = makeAddr("user");
        executor = new HorizonDestinationExecutor(address(this));
        router = new MockSlipstreamSwapRouter();
        musd = new MockERC20("Mock MUSD", "mMUSD");
        peer = new MockERC20("Vault Peer", "vPEER");

        executor.setConfig(address(router), npm, address(musd));
        executor.setPeerToken(address(peer), true);

        // Seed router with MUSD inventory for 1:1 swaps.
        musd.mint(address(router), 1_000_000 ether);
        peer.mint(user, 10_000 ether);
        peer.mint(address(executor), 5_000 ether);
    }

    function test_swapExactIn_pullsShortfallFromOwner() public {
        uint256 held = peer.balanceOf(address(executor));
        uint256 shortfall = 1_000 ether;
        uint256 amountIn = held + shortfall;
        peer.mint(address(this), shortfall);
        peer.approve(address(executor), shortfall);

        uint256 out = executor.swapExactIn(
            address(peer), address(musd), amountIn, amountIn, user, TICK_SPACING
        );

        assertEq(out, amountIn);
        assertEq(musd.balanceOf(user), amountIn);
        assertEq(peer.balanceOf(address(executor)), 0);
    }

    function test_swapExactIn_usesInContractBalance() public {
        uint256 amountIn = 2_000 ether;
        // Owner spends mint-to-executor balance (no pull from caller).
        uint256 out = executor.swapExactIn(
            address(peer), address(musd), amountIn, amountIn, user, TICK_SPACING
        );

        assertEq(out, amountIn);
        assertEq(musd.balanceOf(user), amountIn);
        assertEq(peer.balanceOf(address(executor)), 5_000 ether - amountIn);
    }

    function test_swapExactIn_revertsForNonOwner() public {
        uint256 amountIn = 100 ether;
        vm.prank(user);
        vm.expectRevert();
        executor.swapExactIn(address(peer), address(musd), amountIn, 1, user, TICK_SPACING);
    }

    function test_mintLp_revertsNotImplemented() public {
        vm.expectRevert(bytes("not implemented"));
        executor.mintLp();
    }

    function test_swapExactIn_rejectsUnallowedToken() public {
        MockERC20 other = new MockERC20("Other", "OTH");
        other.mint(address(executor), 100 ether);

        vm.expectRevert(
            abi.encodeWithSelector(HorizonDestinationExecutor.TokenNotAllowed.selector, address(other))
        );
        executor.swapExactIn(address(other), address(musd), 100 ether, 1, user, TICK_SPACING);
    }
}
