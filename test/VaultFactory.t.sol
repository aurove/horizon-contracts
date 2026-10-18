// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, Vm} from "forge-std/Test.sol";

import {Vault} from "../src/Vault.sol";
import {VaultFactory} from "../src/VaultFactory.sol";
import {IVaultFactory} from "../src/interfaces/IVaultFactory.sol";
import {MockId20} from "./mocks/MockId20.sol";
import {MockId20Gauge} from "./mocks/MockId20Gauge.sol";

contract SpoofRewardSinkOnly {
    address public sink;

    constructor(address sink_) {
        sink = sink_;
    }

    function rewardSink() external view returns (address) {
        return sink;
    }
}

contract VaultFactoryTest is Test {
    address internal constant FAKE_ERC1155 = address(0x1155);

    VaultFactory internal factory;
    MockId20 internal id20A;
    MockId20 internal id20B;

    function setUp() public {
        factory = new VaultFactory();
        id20A = new MockId20("avBTCm", "avBTCm", FAKE_ERC1155, 0x010004);
        id20B = new MockId20("avMEZOm", "avMEZOm", FAKE_ERC1155, 0x0200d0);
    }

    function test_createVault_registersAndActivates() public {
        address vaultAddr =
            factory.createVault(address(id20A), "avBTC Vault", "avBTCv");

        assertEq(factory.getVault(address(id20A)), vaultAddr);
        assertTrue(factory.isVault(vaultAddr));
        assertEq(factory.allVaultsLength(), 1);
        assertEq(factory.allVaults(0), vaultAddr);

        MockId20Gauge gauge = id20A.mockGauge();
        assertTrue(gauge.accountState(vaultAddr).isActivated);
        assertFalse(gauge.accountState(address(factory)).isActivated);

        Vault vault = Vault(vaultAddr);
        assertEq(vault.asset(), address(id20A));
        assertEq(vault.name(), "avBTC Vault");
        assertEq(vault.symbol(), "avBTCv");
    }

    function test_createVault_revertsOnDuplicate() public {
        address first = factory.createVault(address(id20A), "avBTC Vault", "avBTCv");
        vm.expectRevert(
            abi.encodeWithSelector(IVaultFactory.VaultAlreadyExists.selector, address(id20A), first)
        );
        factory.createVault(address(id20A), "other", "OTH");
    }

    function test_getOrCreateVault_idempotentIgnoresNameSymbol() public {
        address first = factory.createVault(address(id20A), "avBTC Vault", "avBTCv");
        address second = factory.getOrCreateVault(address(id20A), "ignored", "IGNORED");
        assertEq(first, second);
        assertEq(Vault(first).name(), "avBTC Vault");
        assertEq(Vault(first).symbol(), "avBTCv");
    }

    function test_getOrCreateVault_createsWhenMissing() public {
        address vaultAddr = factory.getOrCreateVault(address(id20B), "avMEZO Vault", "avMEZOv");
        assertEq(factory.getVault(address(id20B)), vaultAddr);
        assertEq(factory.allVaultsLength(), 1);
    }

    function test_multipleVaults() public {
        address v1 = factory.createVault(address(id20A), "avBTC Vault", "avBTCv");
        address v2 = factory.createVault(address(id20B), "avMEZO Vault", "avMEZOv");
        assertEq(factory.allVaultsLength(), 2);
        assertTrue(v1 != v2);
        assertEq(factory.getVault(address(id20A)), v1);
        assertEq(factory.getVault(address(id20B)), v2);
    }

    function test_createVault_revertsZeroAsset() public {
        vm.expectRevert(IVaultFactory.ZeroAddress.selector);
        factory.createVault(address(0), "x", "x");
    }

    function test_createVault_rejectsIncompleteSpoof() public {
        // rewardSink() only — missing id20()/asset()/id()
        SpoofRewardSinkOnly spoof = new SpoofRewardSinkOnly(address(1));
        vm.expectRevert();
        factory.createVault(address(spoof), "x", "x");
    }

    function test_createVault_rejectsZeroId() public {
        MockId20 bad = new MockId20("bad", "bad", FAKE_ERC1155, 0);
        vm.expectRevert(
            abi.encodeWithSelector(IVaultFactory.InvalidId20Asset.selector, address(bad))
        );
        factory.createVault(address(bad), "x", "x");
    }

    function test_emitVaultCreated() public {
        vm.recordLogs();
        address vaultAddr = factory.createVault(address(id20A), "avBTC Vault", "avBTCv");
        Vm.Log[] memory entries = vm.getRecordedLogs();

        bytes32 topic0 = keccak256("VaultCreated(address,address,address,string,string)");
        bool found;
        for (uint256 i; i < entries.length; ++i) {
            if (entries[i].topics.length > 0 && entries[i].topics[0] == topic0) {
                assertEq(address(uint160(uint256(entries[i].topics[1]))), address(id20A));
                assertEq(address(uint160(uint256(entries[i].topics[2]))), vaultAddr);
                assertEq(
                    address(uint160(uint256(entries[i].topics[3]))), address(id20A.mockGauge())
                );
                found = true;
            }
        }
        assertTrue(found, "VaultCreated not emitted");
    }
}
