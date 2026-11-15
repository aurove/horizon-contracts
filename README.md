# Horizon Contracts

Technical reference for `@aurove/horizon-contracts`: ERC-4626 vaults over Aurove Id20 assets, Base-side `VaultPeer` tokens for Wormhole NTT, and the destination executor used after cross-chain delivery.

Package root: `horizon/contracts` inside the [Horizon](https://github.com/aurove/horizon) workspace. License: **MIT**.

Design notes: [`docs/vault-design.md`](./docs/vault-design.md). Hackathon address book and demo txs: [`../SUBMISSION.md`](../SUBMISSION.md).

---

## Contract inventory

| Contract | Path | Role |
|----------|------|------|
| `Vault` | `src/Vault.sol` | Immutable ERC-4626 vault over one Id20. Compounds attributable Id20Gauge rewards via `compound` / `harvestAndCompound`. |
| `VaultFactory` | `src/VaultFactory.sol` | Permissionless one-vault-per-asset registry (`createVault` / `getOrCreateVault`). |
| `VaultPeer` | `src/VaultPeer.sol` | Base-side ERC-20 representation of a Mezo vault share. The NTT manager is the only minter/burner after handoff. |
| `HorizonDestinationExecutor` | `src/HorizonDestinationExecutor.sol` | Optional post-NTT destination helper (e.g. swap into MUSD / LP paths). |
| Interfaces | `src/interfaces/` | `IVault`, `IVaultFactory`, `IVaultPeer`. |
| Vendor | `src/vendor/aurove/` | Aurove Id20 / gauge / rewards-sink interfaces used by the vault. |

Managed share defaults:

| Share | Underlying Id20 (Mezo) | Hub vault | Spoke peer (Base) |
|-------|------------------------|-----------|-------------------|
| `avBTCv` | `avBTCm` | Mezo `Vault` | Base `VaultPeer` |
| `avMEZOv` | `avMEZOm` | Mezo `Vault` | Base `VaultPeer` |

Solidity type names stay `Vault` / `VaultFactory` / `VaultPeer`. “Horizon” is the package/project name only.

---

## Tooling

| Tool | Setting |
|------|---------|
| Solidity | `0.8.28` |
| EVM | `cancun` |
| Optimizer | enabled, `runs: 200`, `viaIR: true` |
| OpenZeppelin | `5.4.0` |
| Hardhat | `^2.28.6` (source of truth for compiler settings) |
| Foundry | forge-std `1.16.1` — keep `foundry.toml` aligned with Hardhat |
| ethers | `^6.16.0` + TypeChain factories |

```text
src/                 # Vault, VaultFactory, VaultPeer, HorizonDestinationExecutor
test/                # Forge unit, ERC-4626 properties, invariants
test/fork/           # Optional Mezo fork coverage (needs RPC)
deploy/scripts/      # hardhat-deploy tags: VaultFactory, Vaults, VaultPeers, Verify
tasks/               # Operational Hardhat tasks (VaultPeer minter handoff)
deployments/         # Recorded addresses per network
helpers/             # Id20 address maps for managed vaults
docs/vault-design.md
```

---

## Development setup

Prerequisites:

- Node.js 20+ and [pnpm](https://pnpm.io)
- [Foundry](https://book.getfoundry.sh/getting-started/installation) (`forge`, `cast`)
- Git

From the Horizon workspace root (`horizon/`):

```bash
git submodule update --init --recursive
pnpm install
```

Then either work from the workspace root or enter this package:

```bash
# From horizon/
pnpm build
pnpm test

# Or from horizon/contracts/
pnpm build
pnpm test
```

`pnpm build` runs `forge build` then Hardhat compile (TypeChain output under `typechain/`). Always invoke Hardhat via **`pnpm hh`** (preload shim for `zksync-ethers`); bare `hardhat` / `pnpm exec hardhat` can fail to boot.

### Environment

```bash
cp .env.example .env
```

| Variable | Required for | Purpose |
|----------|--------------|---------|
| `MEZO_TESTNET_RPC_URL` | Deploy / verify testnet | Default `https://rpc.test.mezo.org` |
| `BASE_SEPOLIA_RPC_URL` | Deploy / verify peers | Default `https://sepolia.base.org` |
| `TESTNET_PRIVATE_KEY` | Mezo testnet deploy | Deployer key (never commit) |
| `BASE_SEPOLIA_PRIVATE_KEY` | Base Sepolia peer deploy | Often the same key as testnet |
| `BASESCAN_API_KEY` | Base verification | Or `ETHERSCAN_API_KEY` (Etherscan API V2) |
| `MEZO_MAINNET_RPC_URL` | Mainnet deploy / fork tests | Mezo mainnet RPC |
| `ALLOW_UNSEEDED_VAULT` | Managed vault deploy | Set `1` to allow deploy when deployer cannot seed dead shares |
| `FORK_ENABLED` | Hardhat fork | Set `1` to fork Mezo in the Hardhat network |

Mezo Blockscout verification does not need an API key. Do not commit private keys or service secrets.

---

## Tests

Unit, property, and invariant suites use Foundry:

```bash
# From horizon/contracts (or `pnpm test` from horizon/)
pnpm test
# equivalent: forge test
```

Useful filters:

```bash
forge test --match-contract VaultTest -vv
forge test --match-path 'test/VaultERC4626.t.sol' -vv
forge test --match-path 'test/invariant/*' -vv
```

Optional Hardhat mocha suite (deploy helpers):

```bash
pnpm test:deploy
```

Optional Mezo fork tests (RPC required; prefer mainnet ABI for current gauge `accountState`):

```bash
MEZO_MAINNET_RPC_URL=https://rpc-internal.mezo.org \
  forge test --match-path 'test/fork/*' -vv
```

Formatting / types:

```bash
pnpm fmt
pnpm typecheck
```

---

## Deploy to testnet

Deployments are recorded under `deployments/<network>/` via hardhat-deploy.

### 1. Mezo testnet — factory + managed vaults

Needs `TESTNET_PRIVATE_KEY` and a funded deployer. Managed vaults seed `1e12` Id20 assets and move shares to `0x…dEaD` when the deployer holds enough Id20 (skipped if dead shares already exist).

```bash
# From horizon/contracts/ — use `pnpm hh` (zksync-ethers preload shim), not bare `hardhat`
pnpm hh deploy --tags VaultFactory,Vaults --network testnet

# Or scoped scripts:
pnpm deploy:factory --network testnet
pnpm deploy:vaults --network testnet
```

Tags:

| Tag | Script | Effect |
|-----|--------|--------|
| `VaultFactory` | `deploy/scripts/00_factory.ts` | Deploy factory |
| `Vaults` | `deploy/scripts/01_vaults.ts` | `createVault` for avBTCm / avMEZOm + dead-share seed |
| `VaultPeers` | `deploy/scripts/02_vault_peers.ts` | Deploy Base `VaultPeer` tokens |
| `Verify` | `deploy/scripts/99_verify.ts` | Submit explorers / Sourcify |

### 2. Base Sepolia — VaultPeers

```bash
pnpm deploy:peer:testnet
# = pnpm hh deploy --tags VaultPeers --network baseSepolia
```

### 3. VaultPeer minter handoff (after NTT managers exist)

The peer deployer is a temporary owner. Setting the NTT manager as minter seals mint/burn and renounces ownership in the same transaction (irreversible):

```bash
pnpm hh vault-peer:set-minter \
  --network baseSepolia \
  --peer <PEER_ADDRESS> \
  --manager <NTT_MANAGER_ADDRESS>
```

### 4. Full cross-chain path (recommended)

From the Horizon workspace root, deploy Mezo vaults, Base peers, Wormhole NTT, and peer minter handoff together:

```bash
# From horizon/
pnpm deploy:cross-chain:testnet
```

Fresh local records + new on-chain deployments (previous addresses remain live):

```bash
CONFIRM_HORIZON_DEPLOYMENT=YES CONFIRM_HORIZON_REDEPLOYMENT=YES \
  pnpm redeploy:cross-chain:testnet
```

(`CONFIRM_CONTRACTS_REDEPLOYMENT` / `CONFIRM_NTT_REDEPLOYMENT` are set internally by the root script when those flags are present.)

`HorizonDestinationExecutor` is deployed via Foundry script (`script/DeployHorizonDestinationExecutor.s.sol`); see [`../docs/destination-executor.md`](../docs/destination-executor.md) and `scripts/broadcast-destination-executor.sh`.

---

## Verification

Verification runs by default after deploy/redeploy when the `Verify` tag executes. You can also run it alone:

```bash
pnpm run verify:testnet          # Mezo testnet (Blockscout + Sourcify v2)
pnpm run verify:base-sepolia     # Base Sepolia (needs BASESCAN_API_KEY)
```

Workspace-level verify (contracts + NTT artifacts):

```bash
# From horizon/
pnpm verify:cross-chain:testnet
```

| Explorer | Networks | Notes |
|----------|----------|-------|
| Mezo Blockscout | `testnet` `31611`, `mainnet` `31612` | Public API; key unused |
| Sourcify | Factory-created vaults | Preferred when Blockscout mis-detects CREATE addresses |
| Basescan | `baseSepolia` `84532`, `base` `8453` | Requires `BASESCAN_API_KEY` |

---

## Testnet deployment addresses

Wave 2 redeploy (2026-11-10). Canonical JSON: `deployments/testnet/`, `deployments/baseSepolia/`. Deployer / NTT owner: `0x6E1126EA838DA392A55D8DdeD9bADEccA5835114`.

### Mezo testnet (`31611`)

| Contract | Address | Verification |
|----------|---------|--------------|
| `VaultFactory` | [`0x48E6cF84FFEd65AeB7Ee560123065606Df4D1f99`](https://explorer.test.mezo.org/address/0x48E6cF84FFEd65AeB7Ee560123065606Df4D1f99#code) | Blockscout verified |
| `avBTCVault` (`avBTCv`) | [`0x8e95C83A5144dcdD6ce79D7fBd58057b689f086f`](https://explorer.test.mezo.org/address/0x8e95C83A5144dcdD6ce79D7fBd58057b689f086f) | [Sourcify](https://repo.sourcify.dev/31611/0x8e95C83A5144dcdD6ce79D7fBd58057b689f086f) verified |
| `avMEZOVault` (`avMEZOv`) | [`0x2C45a18a23d5bfFf3Fc0c4Bff6376dA1d943373c`](https://explorer.test.mezo.org/address/0x2C45a18a23d5bfFf3Fc0c4Bff6376dA1d943373c) | [Sourcify](https://repo.sourcify.dev/31611/0x2C45a18a23d5bfFf3Fc0c4Bff6376dA1d943373c) verified |

Underlying Id20 assets (from vault `linkedData`):

| Asset | Address |
|-------|---------|
| avBTC Id20 (`avBTCm`) | `0xf2aeB53d71CD541EFeaA37788F0841D7d21612F9` |
| avMEZO Id20 (`avMEZOm`) | `0x0aeDdEaB271Bc032d6758c34Dc8356632D6F812e` |

Factory-created vaults are verified on Sourcify. Mezo Blockscout may still report “not a smart-contract” for those CREATE addresses even when RPC bytecode and Sourcify matches are live.

### Base Sepolia (`84532`)

| Contract | Address | Verification |
|----------|---------|--------------|
| `avBTCv` peer | [`0x0d36e2B7350950662859A82A91E13Ad7d0E594E0`](https://sepolia.basescan.org/address/0x0d36e2B7350950662859A82A91E13Ad7d0E594E0#code) | Basescan verified |
| `avMEZOv` peer | [`0x172096f3F0F98B9dc1302695A48044D6A3D799C9`](https://sepolia.basescan.org/address/0x172096f3F0F98B9dc1302695A48044D6A3D799C9#code) | Basescan verified |
| `HorizonDestinationExecutor` | [`0xA874C686D513B079A02399B4dAFC36669C23Ad5b`](https://sepolia.basescan.org/address/0xA874C686D513B079A02399B4dAFC36669C23Ad5b#code) | Basescan verified |

Peer minters are sealed to the spoke NTT managers; peer ownership is renounced after handoff.

### Related Wormhole NTT (sibling package)

NTT managers/transceivers live under [`../wormhole`](../wormhole) (`wormhole/vaults/*/testnet/deployment.json`). Summary for Wave 2 testnet:

#### avBTCv

| Chain | Role | Address |
|-------|------|---------|
| Mezo | NTT manager (locking) | `0x01B2C64505f367203429753029EA8BEB66987a09` |
| Mezo | Wormhole transceiver | `0xA21328Abc178E1b47eC9A14f40e7100372678d10` |
| Base Sepolia | NTT manager (burning) | `0x96e12AD5F0402a458823A8E2A6Ea0E986DCD358e` |
| Base Sepolia | Wormhole transceiver | `0x82C8d99f67eB28b023387236051cB292c9A477AA` |

#### avMEZOv

| Chain | Role | Address |
|-------|------|---------|
| Mezo | NTT manager (locking) | `0x2a0B2726f7822cEBdE9D665D049a42f13Fa6A517` |
| Mezo | Wormhole transceiver | `0x6201F4c88aAfDd627108467dafA81464E3eb885a` |
| Base Sepolia | NTT manager (burning) | `0x79D11c9d7F5d5ef676c4c87Cf9deEC5D972bd8A1` |
| Base Sepolia | Wormhole transceiver | `0x9383b1ACAf2bD2B0F6b205Be9fFbCcBfC78A8300` |

---

## Networks

| Network | Chain ID | Hardhat name | Default RPC |
|---------|----------|--------------|-------------|
| Mezo testnet | `31611` | `testnet` | `https://rpc.test.mezo.org` |
| Mezo mainnet | `31612` | `mainnet` | set `MEZO_MAINNET_RPC_URL` |
| Base Sepolia | `84532` | `baseSepolia` | `https://sepolia.base.org` |
| Base | `8453` | `base` | `https://mainnet.base.org` |
| Local node | — | `localhost` | `http://127.0.0.1:8545` |

Optional Hardhat forking: `FORK_ENABLED=1` (and optionally `FORK_RPC_URL` / `FORK_BLOCK_NUMBER`).

---

## Mainnet / redeploy notes

- Mainnet vault deploy: `pnpm hh deploy --tags VaultFactory,Vaults --network mainnet` with `MAINNET_PRIVATE_KEY` and `CONFIRM_HORIZON_MAINNET_DEPLOYMENT=YES` where the root workflow requires it.
- Base mainnet peers: `pnpm deploy:peer:mainnet`.
- Package reset scripts (`pnpm redeploy:testnet` / `pnpm redeploy:mainnet`) delete **local** deployment records then deploy new contracts. Prior on-chain addresses remain live; only the JSON bookkeeping is replaced.
- For a complete hub+spoke refresh, prefer `pnpm redeploy:cross-chain:testnet` from `horizon/` so NTT managers and peer minters target the new addresses.

---

## Related packages

| Package | Path | Role |
|---------|------|------|
| `@aurove/horizon-wormhole` | [`../wormhole`](../wormhole) · [`docs/ntt-design.md`](../wormhole/docs/ntt-design.md) | Wormhole NTT configs, deploy/verify helpers |
| `@aurove/horizon-aero` | [`../aero`](../aero) | Base Sepolia Slipstream / CL200 pools vs MUSD |
| dApp | [`aurove/dapp` (`testnet`)](https://github.com/aurove/dapp/tree/testnet) | Bridge + Base swap UI against these addresses |
