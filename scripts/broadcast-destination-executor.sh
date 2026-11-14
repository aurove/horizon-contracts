#!/usr/bin/env bash
# Broadcast HorizonDestinationExecutor on Base Sepolia and wire Slipstream + MUSD + peers.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HORIZON="$(cd "$ROOT/.." && pwd)"
ADDRESSES="$HORIZON/aero/deployments/baseSepolia/addresses.json"
PEERS_DIR="$ROOT/deployments/baseSepolia"

if [[ ! -f "$ADDRESSES" ]]; then
  echo "Missing $ADDRESSES — deploy Slipstream first." >&2
  exit 1
fi

# shellcheck disable=SC1091
set -a
[[ -f "$HORIZON/.env" ]] && source "$HORIZON/.env"
set +a

PK="${PRIVATE_KEY:-${ETH_PRIVATE_KEY:-}}"
if [[ -z "$PK" ]]; then
  echo "Set PRIVATE_KEY or ETH_PRIVATE_KEY" >&2
  exit 1
fi
[[ "$PK" == 0x* ]] || PK="0x$PK"

RPC="${BASE_SEPOLIA_RPC_URL:-https://sepolia.base.org}"
SWAP_ROUTER="$(python3 -c "import json;print(json.load(open('$ADDRESSES')).get('SwapRouter') or '')")"
NPM="$(python3 -c "import json;print(json.load(open('$ADDRESSES')).get('NonfungiblePositionManager') or '')")"
MUSD="$(python3 -c "import json;d=json.load(open('$ADDRESSES'));print(d.get('MUSD') or '')")"
MUSD="${MUSD_ADDRESS:-$MUSD}"
PEER_MEZO="$(python3 -c "import json;print(json.load(open('$PEERS_DIR/avMEZOvPeer.json'))['address'])" 2>/dev/null || true)"
PEER_BTC="$(python3 -c "import json;print(json.load(open('$PEERS_DIR/avBTCvPeer.json'))['address'])" 2>/dev/null || true)"

if [[ -z "$SWAP_ROUTER" || -z "$NPM" || -z "$MUSD" ]]; then
  echo "Need SwapRouter, NPM, and MUSD in address book (or MUSD_ADDRESS)." >&2
  exit 1
fi

echo "Broadcasting HorizonDestinationExecutor…"
echo "  SWAP_ROUTER=$SWAP_ROUTER"
echo "  NPM=$NPM"
echo "  MUSD=$MUSD"
echo "  PEER_MEZO=$PEER_MEZO"
echo "  PEER_BTC=$PEER_BTC"

cd "$ROOT"
OUT=$(PRIVATE_KEY="$PK" SWAP_ROUTER="$SWAP_ROUTER" NPM="$NPM" MUSD="$MUSD" \
  PEER_TOKEN="${PEER_MEZO:-}" \
  forge script script/DeployHorizonDestinationExecutor.s.sol:DeployHorizonDestinationExecutor \
  --rpc-url "$RPC" --broadcast -vv 2>&1)
echo "$OUT"
EXEC=$(echo "$OUT" | awk '/HorizonDestinationExecutor/{print $NF; exit}')
if [[ -z "$EXEC" || "$EXEC" != 0x* ]]; then
  echo "Could not parse executor address from forge output" >&2
  exit 1
fi

# Allowlist BTC peer if present (MEZO peer already set via PEER_TOKEN)
if [[ -n "$PEER_BTC" ]]; then
  echo "Allowlisting avBTCvPeer $PEER_BTC on executor $EXEC"
  cast send "$EXEC" "setPeerToken(address,bool)" "$PEER_BTC" true \
    --private-key "$PK" --rpc-url "$RPC"
fi

mkdir -p "$HORIZON/aero/deployments/baseSepolia"
python3 - <<PY
import json
from pathlib import Path
p = Path("$ADDRESSES")
book = json.loads(p.read_text())
book["HorizonDestinationExecutor"] = "$EXEC"
p.write_text(json.dumps(book, indent=2) + "\n")
print("Wrote HorizonDestinationExecutor to", p)
PY
