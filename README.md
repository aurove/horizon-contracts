# Horizon Contracts

Smart contracts for Aurove Horizon: ERC-4626 vaults over eligible Id20 assets, with cross-chain share mobility planned via Wormhole NTT.

This package mirrors the Foundry + Hardhat tooling used by `@aurove/id20` and `@aurove/core`.

## Tooling

| Tool | Version / setting |
|------|-------------------|
| Solidity | `0.8.28` |
| EVM | `cancun` |
| Optimizer | enabled, `runs: 200`, `viaIR: true` |
| OpenZeppelin | `5.4.0` |
| Hardhat | `^2.28.6` |
| ethers | `^6.16.0` |
| forge-std | `1.16.1` (Foundry lib) |

Hardhat is the source of truth for compiler settings; keep `foundry.toml` in lockstep.

## Layout

```text
src/                 # Solidity sources (create when adding contracts)
test/                # Forge tests (*.t.sol)
test/hardhat/        # Hardhat / TypeScript tests
deploy/scripts/      # hardhat-deploy scripts
lib/                 # Foundry dependencies (forge-std, openzeppelin-contracts)
```

Configured paths are created as you add sources, tests, and deploy scripts.

## Setup

From the aurove monorepo root (pnpm workspace includes this package):

```bash
pnpm install
pnpm --filter @aurove/horizon-contracts build
pnpm --filter @aurove/horizon-contracts test
```

Or from this directory after installing Foundry libs:

```bash
git submodule update --init --recursive
pnpm install
pnpm build
pnpm test
```

Copy `.env.example` to `.env` for network keys and RPC URLs.

## Networks

| Network | Chain ID | Default RPC |
|---------|----------|-------------|
| Mezo testnet | `31611` | `https://rpc.test.mezo.org` |
| Mezo mainnet | `31612` | set `MAINNET_RPC_URL` |

Optional Hardhat forking: set `FORK_ENABLED=1` (and optionally `FORK_RPC_URL` / `FORK_BLOCK_NUMBER`).
