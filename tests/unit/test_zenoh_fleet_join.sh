#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export COREBRUM_ROOT="$ROOT"
# shellcheck source=../../scripts/lib/log.sh
source "${ROOT}/scripts/lib/log.sh"
# shellcheck source=../../scripts/lib/zenoh-fleet.sh
source "${ROOT}/scripts/lib/zenoh-fleet.sh"

bin="$(mktemp -d)"
etc="$(mktemp -d)"
fleet="$(mktemp -d)"
token_dir="$(mktemp -d)"

export COREBRUM_ZENOH_ETC="$etc"
export COREBRUM_ZENOH_SYSTEMCTL=true
export HOME="$token_dir"
mkdir -p "${HOME}/.config/configstore"
printf '{"API_TOKEN":"test-token"}\n' >"${HOME}/.config/configstore/synapse.json"

cat >"${bin}/sudo" <<'SCRIPT'
#!/usr/bin/env bash
exec "$@"
SCRIPT
chmod +x "${bin}/sudo"
cat >"${bin}/corebrum" <<SCRIPT
#!/usr/bin/env bash
set -euo pipefail
export COREBRUM_ROOT="${ROOT}"
export COREBRUM_ZENOH_ETC="${etc}"
export COREBRUM_ZENOH_SYSTEMCTL=true
# shellcheck source=../../scripts/lib/log.sh
source "${ROOT}/scripts/lib/log.sh"
# shellcheck source=../../scripts/lib/zenoh-fleet.sh
source "${ROOT}/scripts/lib/zenoh-fleet.sh"
if [[ "\${1:-}" == zenoh && "\${2:-}" == fleet && "\${3:-}" == sync ]]; then
  corebrum_cmd_zenoh_fleet_sync "\${4:-}"
  exit 0
fi
echo "unexpected corebrum: \$*" >&2
exit 1
SCRIPT
chmod +x "${bin}/corebrum"
cat >"${bin}/zenoh-fleet" <<'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail
out=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    pull) shift ;;
    --out) out="$2"; shift 2 ;;
    *) shift ;;
  esac
done
[[ -n "$out" ]] || { echo "missing --out" >&2; exit 1; }
mkdir -p "$out"
cat >"$out/fleet.json" <<'EOF'
{
  "name": "cloud-fleet",
  "role": "member",
  "hubEndpoints": ["tcp/192.168.8.196:7447"]
}
EOF
cat >"$out/rmw-zenoh-session.json5" <<'EOF'
{ mode: "client" }
EOF
SCRIPT
chmod +x "${bin}/zenoh-fleet"
export PATH="${bin}:${PATH}"

corebrum_cmd_zenoh_fleet_join "${fleet}" >/dev/null
grep -q 'tcp://192.168.8.196:7447' "${etc}/corebrum/zenoh/router"
[[ -f "${fleet}/fleet.json" ]] || { echo "FAIL: fleet.json missing after join" >&2; exit 1; }

rm -rf "$bin" "$etc" "$fleet" "$token_dir"
echo "ok: zenoh fleet join"
