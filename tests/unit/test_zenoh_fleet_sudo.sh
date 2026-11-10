#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export COREBRUM_ROOT="$ROOT"

run_as_root() {
  # shellcheck source=../../scripts/lib/log.sh
  source "${ROOT}/scripts/lib/log.sh"
  # shellcheck source=../../scripts/lib/zenoh-fleet.sh
  source "${ROOT}/scripts/lib/zenoh-fleet.sh"

  invoke_home="$(mktemp -d)"
  export HOME="/root"
  export SUDO_USER="fleet-sudo-test"
  mkdir -p "${invoke_home}/.config/configstore"
  printf '{"API_TOKEN":"sudo-test-token"}\n' >"${invoke_home}/.config/configstore/synapse.json"

  bin="$(mktemp -d)"
  cat >"${bin}/getent" <<SCRIPT
#!/usr/bin/env bash
if [[ "\${2:-}" == "fleet-sudo-test" ]]; then
  echo "fleet-sudo-test:x:65534:65534::${invoke_home}:/bin/false"
  exit 0
fi
if [[ -x /usr/bin/getent ]]; then
  exec /usr/bin/getent "\$@"
fi
exec /bin/getent "\$@"
SCRIPT
  chmod +x "${bin}/getent"
  export PATH="${bin}:${PATH}"

  got="$(corebrum_zenoh_config_home)"
  [[ "$got" == "$invoke_home" ]] || {
    echo "FAIL: config_home=${got}, want ${invoke_home}" >&2
    exit 1
  }
  corebrum_zenoh_read_api_token >/dev/null

  rm -rf "$invoke_home" "$bin"
  echo "ok: zenoh fleet sudo config home"
}

if [[ "$(id -u)" -eq 0 ]]; then
  run_as_root
elif sudo -n true 2>/dev/null; then
  sudo env COREBRUM_ROOT="$ROOT" bash "$0"
else
  echo "skip: zenoh fleet sudo (need passwordless sudo to run as root)" >&2
  exit 0
fi
