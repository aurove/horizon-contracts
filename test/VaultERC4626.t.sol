// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ERC4626Test} from "erc4626-tests/ERC4626.test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {Vault} from "../src/Vault.sol";
import {MockId20} from "./mocks/MockId20.sol";

/// @dev a16z ERC-4626 property suite against Vault + MockId20.
contract VaultERC4626Test is ERC4626Test {
    address internal constant FAKE_ERC1155 = address(0x1155);

    function setUp() public override {
        MockId20 underlying = new MockId20("avBTCm", "avBTCm", FAKE_ERC1155, 0x010004);
        _underlying_ = address(underlying);
        _vault_ = address(new Vault(IERC20(_underlying_), "avBTC Vault", "avBTCv"));
        _delta_ = 0;
        _vaultMayBeEmpty = true;
        _unlimitedAmount = true;
    }
}
