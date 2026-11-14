#!/usr/bin/env bash
set -euo pipefail

network="${1:-}"
case "$network" in
  testnet)
    hub_network="testnet"
    spoke_network="baseSepolia"
    spoke_verify="base-sepolia"
    ;;
  mainnet)
    hub_network="mainnet"
    spoke_network="base"
    spoke_verify="base"
    if [[ "${CONFIRM_HORIZON_MAINNET_DEPLOYMENT:-}" != "YES" ]]; then
      echo "Set CONFIRM_HORIZON_MAINNET_DEPLOYMENT=YES before redeploying mainnet contracts." >&2
      exit 2
    fi
    ;;
  *)
    echo "Usage: pnpm redeploy:<testnet|mainnet>" >&2
    exit 2
    ;;
esac

if [[ "${CONFIRM_CONTRACTS_REDEPLOYMENT:-}" != "YES" ]]; then
  echo "Set CONFIRM_CONTRACTS_REDEPLOYMENT=YES to delete local $network deployment records and deploy fresh contracts." >&2
  exit 2
fi

# hardhat-deploy imports zksync-ethers unconditionally; stub via `pnpm hh`.
pnpm hh deploy --reset --tags VaultFactory,Vaults --network "$hub_network"
pnpm hh deploy --reset --tags VaultPeers --network "$spoke_network"
# Explorer indexing can lag; soft-fail so NTT/configure can proceed. Re-run verify later.
export HORIZON_VERIFY_SOFT_FAIL="${HORIZON_VERIFY_SOFT_FAIL:-YES}"
pnpm run "verify:$hub_network" || echo "WARNING: $hub_network verify failed (continuing)"
pnpm run "verify:$spoke_verify" || echo "WARNING: $spoke_verify verify failed (continuing)"
