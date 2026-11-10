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
corebrum_cmd_zenoh_fleet_apply "$fleet" >"${etc}/hub.out"
grep -q 'tcp://127.0.0.1:7447' "${etc}/corebrum/zenoh/router"
grep -q 'systemctl enable --now corebrum-zenoh-router.service' "${etc}/hub.out"
if [[ -f "${etc}/corebrum/zenoh/rmw-session.json5" ]]; then
  echo "FAIL: hub apply installed a member session" >&2
  exit 1
fi

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
corebrum_cmd_zenoh_fleet_apply "$fleet" >"${etc}/member.out"
grep -q 'tcp://192.168.8.20:7447' "${etc}/corebrum/zenoh/router"
grep -q 'mode: "client"' "${etc}/corebrum/zenoh/rmw-session.json5"
grep -q 'ZENOH_SESSION_CONFIG_URI=' "${etc}/profile.d/corebrum-zenoh-session.sh"
grep -q 'systemctl disable --now corebrum-zenoh-router.service' "${etc}/member.out"
grep -q 'cortex daemon --zenoh-router tcp://192.168.8.20:7447' "${etc}/member.out"

rm -rf "$etc" "$fleet"
echo "ok: zenoh fleet apply"
