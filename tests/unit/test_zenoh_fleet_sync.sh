#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export COREBRUM_ROOT="$ROOT"
# shellcheck source=../../scripts/lib/log.sh
source "${ROOT}/scripts/lib/log.sh"
# shellcheck source=../../scripts/lib/zenoh-fleet.sh
source "${ROOT}/scripts/lib/zenoh-fleet.sh"

etc="$(mktemp -d)"
export COREBRUM_ZENOH_ETC="$etc"
export COREBRUM_ZENOH_SYSTEMCTL=true
fleet="$(mktemp -d)"

cat >"${fleet}/fleet.json" <<'EOF'
{
  "name": "desk",
  "role": "hub",
  "hubEndpoints": ["tcp/192.168.8.20:7447"]
}
EOF

corebrum_cmd_zenoh_fleet_sync "$fleet" >/dev/null
grep -q 'tcp://127.0.0.1:7447' "${etc}/corebrum/zenoh/router"
fp="$(corebrum_zenoh_fleet_applied_fingerprint)"
[[ -n "$fp" ]] || { echo "FAIL: missing applied fingerprint" >&2; exit 1; }

corebrum_cmd_zenoh_fleet_sync "$fleet" >/dev/null

cat >"${fleet}/fleet.json" <<'EOF'
{
  "name": "desk",
  "role": "member",
  "hubEndpoints": ["tcp/192.168.8.20:7447"]
}
EOF
cat >"${fleet}/rmw-zenoh-session.json5" <<'EOF'
{ mode: "client" }
EOF

corebrum_cmd_zenoh_fleet_sync "$fleet" >/dev/null
grep -q 'tcp://192.168.8.20:7447' "${etc}/corebrum/zenoh/router"
new_fp="$(corebrum_zenoh_fleet_applied_fingerprint)"
[[ "$fp" != "$new_fp" ]] || { echo "FAIL: fingerprint did not change after member config" >&2; exit 1; }

rm -rf "$etc" "$fleet"
echo "ok: zenoh fleet sync"
