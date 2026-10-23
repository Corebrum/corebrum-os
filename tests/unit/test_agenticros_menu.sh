#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
menu="${ROOT}/scripts/desktop/corebrum-agenticros-menu.sh"
status="${ROOT}/scripts/desktop/corebrum-agenticros-status.sh"
wrapper="${ROOT}/scripts/desktop/corebrum-agenticros-with-ros.sh"
launcher="${ROOT}/scripts/desktop/corebrum-launcher.sh"
agents="${ROOT}/scripts/desktop/corebrum-agents-menu.sh"

assert_eq() {
  local got="$1" expected="$2" message="$3"
  if [[ "$got" != "$expected" ]]; then
    printf 'FAIL: %s\n got: %q\n expected: %q\n' "$message" "$got" "$expected" >&2
    exit 1
  fi
}

if ! grep -q '/usr/local/bin/corebrum-agenticros-menu refresh' "$launcher"; then
  echo "FAIL: Super+Space does not refresh the AgenticROS entry" >&2
  exit 1
fi
if ! grep -q 'RMW_IMPLEMENTATION=rmw_zenoh_cpp' "$wrapper"; then
  echo "FAIL: AgenticROS wrapper does not force the Zenoh RMW" >&2
  exit 1
fi
if ! grep -q 'agenticros mcp setup --installed --quiet' "$agents"; then
  echo "FAIL: Super+Space refresh does not couple installed agents" >&2
  exit 1
fi

export COREBRUM_AGENTICROS_STUB=1
export COREBRUM_AGENTICROS_ROS=0
export COREBRUM_AGENTICROS_READY=0
runtime="$(mktemp -d)"
export XDG_RUNTIME_DIR="$runtime"
"$menu" refresh
if [[ -e "${runtime}/corebrum/applications/corebrum-agenticros.desktop" ]]; then
  echo "FAIL: AgenticROS is listed before ROS is installed" >&2
  exit 1
fi

export COREBRUM_AGENTICROS_ROS=1
assert_eq "$("$menu" entry-name)" "AgenticROS   install" "missing AgenticROS is offered for install"
got="$("$menu" open)"
if ! grep -q '/usr/local/lib/corebrum/agenticros-install.sh' <<<"$got"; then
  echo "FAIL: choosing AgenticROS did not start the installer" >&2
  exit 1
fi
if ! grep -q 'agenticros init --yes' <<<"$got"; then
  echo "FAIL: first run does not init AgenticROS" >&2
  exit 1
fi
install_script="${ROOT}/scripts/desktop/corebrum-agenticros-install.sh"
if ! grep -q 'build-essential' "$install_script" || ! grep -q 'python3' "$install_script"; then
  echo "FAIL: AgenticROS install does not install the rclnodejs toolchain" >&2
  exit 1
fi

export COREBRUM_AGENTICROS_READY=1
assert_eq "$("$menu" entry-name)" "AgenticROS" "initialized AgenticROS has no install indicator"
"$menu" refresh
if ! grep -q '^Name=AgenticROS$' "${runtime}/corebrum/applications/corebrum-agenticros.desktop"; then
  echo "FAIL: refreshed desktop entry did not name AgenticROS" >&2
  exit 1
fi
export COREBRUM_AGENTICROS_CHOICE="ARC: Connect"
assert_eq "$("$menu" open)" "agenticros connect" "ARC connect uses the CLI"
export COREBRUM_AGENTICROS_CHOICE="Camera: Start RealSense"
assert_eq "$("$menu" open)" "agenticros start realsense" "RealSense start uses the CLI"
export COREBRUM_AGENTICROS_CHOICE="Stack: Real robot"
assert_eq "$("$menu" open)" "agenticros up real" "real robot uses agenticros up"
export COREBRUM_AGENTICROS_CHOICE="Eyes: Stop"
assert_eq "$("$menu" open)" "agenticros stop eyes" "eyes stop uses the CLI"
export COREBRUM_AGENTICROS_CHOICE="Agents: Connect installed CLIs"
assert_eq "$("$menu" open)" "agenticros mcp setup --installed" "agent connect refreshes MCP setup"

export COREBRUM_AGENTICROS_STATUS_JSON='{"hardware":[{"name":"comms","running":true},{"name":"realsense","running":false}],"components":[{"name":"eyes","running":false}],"openclawGatewayActive":false}'
shown="$("$status" show)"
if ! grep -q '"class": "connected"' <<<"$shown"; then
  echo "FAIL: connected ARC did not mark the status connected" >&2
  printf '%s\n' "$shown" >&2
  exit 1
fi
if ! grep -q 'realsense: stopped' <<<"$shown"; then
  echo "FAIL: status tooltip omitted RealSense" >&2
  exit 1
fi
export COREBRUM_AGENTICROS_STATUS_JSON='{"absent":true}'
shown="$("$status" show)"
if ! grep -q '"class": "absent"' <<<"$shown"; then
  echo "FAIL: missing CLI did not hide the status text" >&2
  exit 1
fi
rm -rf "$runtime"

echo "ok: agenticros-menu"
