# Contracts

ERC-4626 vaults over Aurove Id20 assets, with permissionless compounding of attributable Id20Gauge rewards.

This package (`@aurove/horizon-contracts`) mirrors Foundry + Hardhat tooling used by `@aurove/id20` and `@aurove/core`.

## Contracts

| Contract | Role |
|----------|------|
| `Vault` | Immutable ERC-4626 vault over one Id20; `compound` / `harvestAndCompound` |
| `VaultFactory` | Permissionless one-vault-per-asset registry (`createVault` / `getOrCreateVault`) |

Managed share defaults: **avBTCv** / **avMEZOv** over Id20 **avBTCm** / **avMEZOm**.

Design notes: [`docs/vault-design.md`](./docs/vault-design.md).

## Tooling

| Tool | Version / setting |
|------|-------------------|
| Solidity | `0.8.28` |
| EVM | `cancun` |
| Optimizer | enabled, `runs: 200`, `viaIR: true` |
| OpenZeppelin | `5.4.0` |
| Hardhat | `^2.28.6` |
| ethers | `^6.16.0` |
| forge-std | `1.16.1` |

Hardhat is the source of truth for compiler settings; keep `foundry.toml` in lockstep.

## Layout

```text
src/                 # Vault, VaultFactory, interfaces, vendor ABIs
test/                # Forge unit, ERC-4626 properties, invariants
test/fork/           # Mezo testnet fork coverage (needs RPC)
deploy/scripts/      # hardhat-deploy
lib/                 # forge-std, openzeppelin-contracts
docs/vault-design.md
```

## Setup

```bash
git submodule update --init --recursive
pnpm install
pnpm build
pnpm test
```

Fork tests (optional; mainnet ABI — testnet gauges still use legacy `accountMetadata`):

```bash
MAINNET_RPC_URL=https://rpc-internal.mezo.org forge test --match-path 'test/fork/*' -vv
```

Copy `.env.example` to `.env` for network keys and RPC URLs.

## Cross-chain (NTT)

Vault shares are plain ERC-20s intended for Wormhole NTT. Tooling lives in the sibling package [`@aurove/horizon-wormhole`](../wormhole) (`horizon/wormhole`): initialized `deployment.json` files for `avBTCv` / `avMEZOv`, hub Mezo (locking) → Base / BaseSepolia (burning).

## Deploy

```bash
pnpm exec hardhat deploy --tags VaultFactory,Vaults --network testnet
```

Managed vault scripts:

1. Prefer `createVault` for first-shot managed tags.
2. Seed `1e12` Id20 and transfer shares to `0x…dEaD` only if `balanceOf(DEAD) == 0`.
3. Skip seed when the deployer lacks Id20 balance.

## Networks

| Network | Chain ID | Default RPC |
|---------|----------|-------------|
| Mezo testnet | `31611` | `https://rpc.test.mezo.org` |
| Mezo mainnet | `31612` | set `MAINNET_RPC_URL` |

Optional Hardhat forking: set `FORK_ENABLED=1` (and optionally `FORK_RPC_URL` / `FORK_BLOCK_NUMBER`).
