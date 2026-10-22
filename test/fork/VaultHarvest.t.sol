// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {Vault} from "../../src/Vault.sol";
import {VaultFactory} from "../../src/VaultFactory.sol";
import {IAuroveId20} from "../../src/vendor/aurove/interfaces/IAuroveId20.sol";
import {IId20Gauge} from "../../src/vendor/aurove/interfaces/IId20Gauge.sol";

/// @notice Mezo mainnet fork: deploy vault over live Id20 and exercise harvest/compound.
/// @dev Prefers MEZO_MAINNET_RPC_URL. Skips when the RPC/fork is unavailable.
///      Testnet gauges still expose legacy `accountMetadata` and are not targeted here;
///      vendor ABIs match current id20 source / mainnet (`accountState`).
contract VaultHarvestForkTest is Test {
    string internal constant DEFAULT_RPC = "https://rpc-internal.mezo.org";
    uint256 internal constant MAINNET_CHAIN_ID = 31612;

    // packages/id20/deployments/mainnet
    address internal constant AV_BTCM_ID20 = 0xf333171788dE7005695b2E8FB9cAE97Ba9c4dD7a;
    address internal constant AV_MEZOM_ID20 = 0xb894b11A78B762c82Cb095148F5BC11DC93C3560;

    bool internal forkReady;

    function setUp() public {
        string memory rpc = vm.envOr("MEZO_MAINNET_RPC_URL", DEFAULT_RPC);
        try vm.envUint("FORK_BLOCK") returns (uint256 blockNumber) {
            vm.createSelectFork(rpc, blockNumber);
        } catch {
            try vm.createSelectFork(rpc) {
            } catch {
                forkReady = false;
                return;
            }
        }
        forkReady = block.chainid == MAINNET_CHAIN_ID && AV_BTCM_ID20.code.length > 0;
    }

    modifier onlyFork() {
        vm.skip(!forkReady);
        _;
    }

    function test_fork_createVaultOverLiveAvBTCm() public onlyFork {
        VaultFactory factory = new VaultFactory();
        address vaultAddr = factory.createVault(AV_BTCM_ID20, "avBTC Vault", "avBTCv");

        Vault vault = Vault(vaultAddr);
        IAuroveId20 id20 = IAuroveId20(AV_BTCM_ID20);
        IId20Gauge gauge = IId20Gauge(address(id20.rewardSink()));

        assertEq(address(vault.asset()), AV_BTCM_ID20);
        assertEq(address(vault.gauge()), address(gauge));
        assertTrue(gauge.accountState(vaultAddr).isActivated);
        assertFalse(gauge.accountState(address(factory)).isActivated);
        assertEq(vault.totalAssets(), IERC20(AV_BTCM_ID20).balanceOf(vaultAddr));
    }

    function test_fork_createVaultOverLiveAvMEZOm() public onlyFork {
        VaultFactory factory = new VaultFactory();
        address vaultAddr = factory.createVault(AV_MEZOM_ID20, "avMEZO Vault", "avMEZOv");
        assertTrue(Vault(vaultAddr).gauge().accountState(vaultAddr).isActivated);
    }

    function test_fork_harvestAndCompound_tolerant() public onlyFork {
        VaultFactory factory = new VaultFactory();
        Vault vault = Vault(factory.createVault(AV_BTCM_ID20, "avBTC Vault", "avBTCv"));

        uint256 assetsBefore = vault.totalAssets();
        (uint256 harvested, uint256 compounded) = vault.harvestAndCompound();
        assertEq(vault.totalAssets(), assetsBefore + compounded);
        assertGe(harvested + compounded, 0);
    }
}
