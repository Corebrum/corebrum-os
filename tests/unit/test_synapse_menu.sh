#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
menu="${ROOT}/scripts/desktop/corebrum-synapse-menu.sh"
status="${ROOT}/scripts/desktop/corebrum-synapse-status.sh"
wrapper="${ROOT}/scripts/desktop/corebrum-synapse-with-ros.sh"
launcher="${ROOT}/scripts/desktop/corebrum-launcher.sh"
agents="${ROOT}/scripts/desktop/corebrum-agents-menu.sh"

assert_eq() {
  local got="$1" expected="$2" message="$3"
  if [[ "$got" != "$expected" ]]; then
    printf 'FAIL: %s\n got: %q\n expected: %q\n' "$message" "$got" "$expected" >&2
    exit 1
  fi
}

if ! grep -q '/usr/local/bin/corebrum-synapse-menu refresh' "$launcher"; then
  echo "FAIL: Super+Space does not refresh the Corebrum Synapse entry" >&2
  exit 1
fi
if ! grep -q 'RMW_IMPLEMENTATION=rmw_zenoh_cpp' "$wrapper"; then
  echo "FAIL: Corebrum Synapse wrapper does not force the Zenoh RMW" >&2
  exit 1
fi
if ! grep -q 'synapse mcp setup --installed --quiet' "$agents"; then
  echo "FAIL: Super+Space refresh does not couple installed agents" >&2
  exit 1
fi

export COREBRUM_SYNAPSE_STUB=1
export COREBRUM_SYNAPSE_ROS=0
export COREBRUM_SYNAPSE_READY=0
runtime="$(mktemp -d)"
export XDG_RUNTIME_DIR="$runtime"
"$menu" refresh
if [[ -e "${runtime}/corebrum/applications/corebrum-synapse.desktop" ]]; then
  echo "FAIL: Corebrum Synapse is listed before ROS is installed" >&2
  exit 1
fi

export COREBRUM_SYNAPSE_ROS=1
assert_eq "$("$menu" entry-name)" "Corebrum Synapse   install" "missing Corebrum Synapse is offered for install"
got="$("$menu" open)"
if ! grep -q '/usr/local/lib/corebrum/synapse-install.sh' <<<"$got"; then
  echo "FAIL: choosing Corebrum Synapse did not start the installer" >&2
  exit 1
fi
if ! grep -q 'synapse init --yes' <<<"$got"; then
  echo "FAIL: first run does not init Corebrum Synapse" >&2
  exit 1
fi
install_script="${ROOT}/scripts/desktop/corebrum-synapse-install.sh"
if ! grep -q 'build-essential' "$install_script" || ! grep -q 'python3' "$install_script"; then
  echo "FAIL: Corebrum Synapse install does not install the rclnodejs toolchain" >&2
  exit 1
fi
if ! grep -q 'prebuild-install' "$install_script" || ! grep -q 'node-datachannel' "$install_script"; then
  echo "FAIL: Corebrum Synapse install does not install the node-datachannel prebuild" >&2
  exit 1
fi
if ! grep -q 'https://github.com/Corebrum/corebrum-synapse.git' "$install_script"; then
  echo "FAIL: Corebrum Synapse install does not clone github.com/Corebrum/corebrum-synapse" >&2
  exit 1
fi

synapse_prepare() {
  bash --noprofile --norc -c '
set -euo pipefail
source "$1"
corebrum_synapse_prepare_clone
' bash "$install_script"
}

clone_tmp="$(mktemp -d)"
clone_bin="${clone_tmp}/bin"
clone_log="${clone_tmp}/git.log"
mkdir -p "$clone_bin"
cat >"${clone_bin}/git" <<'EOF'
#!/bin/bash
printf '%s\n' "$*" >>"${GIT_LOG:?}"
if [[ "${GIT_MODE:-clone}" != clone ]]; then
  dest="${@: -1}"
  mkdir -p "$dest"
  exit 0
fi
[[ "$1" == clone ]] || exit 1
dest="${@: -1}"
mkdir -p "$dest"
printf 'packages:\n' >"$dest/pnpm-workspace.yaml"
EOF
chmod 755 "${clone_bin}/git"

checkout="${clone_tmp}/home/corebrum-os"
mkdir -p "${checkout}/scripts"
touch "${checkout}/scripts/corebrum.sh"
got="$(
  export GIT_LOG="$clone_log"
  export PATH="${clone_bin}:/usr/bin:/bin"
  export COREBRUM_ROOT="$checkout"
  unset COREBRUM_SYNAPSE_ROOT COREBRUM_SYNAPSE_URL
  synapse_prepare 2>/dev/null
)"
assert_eq "$got" "${clone_tmp}/home/synapse" "missing Corebrum Synapse is cloned beside the Corebrum checkout"
if ! grep -qF "clone --depth 1 https://github.com/Corebrum/corebrum-synapse.git ${clone_tmp}/home/synapse" "$clone_log"; then
  echo "FAIL: clone did not use https://github.com/Corebrum/corebrum-synapse.git" >&2
  printf '%s\n' "$(cat "$clone_log")" >&2
  exit 1
fi
printf 'keep\n' >"${clone_tmp}/home/synapse/marker"
: >"$clone_log"
got="$(
  export GIT_LOG="$clone_log"
  export PATH="${clone_bin}:/usr/bin:/bin"
  export COREBRUM_SYNAPSE_ROOT="${clone_tmp}/home/synapse"
  unset COREBRUM_SYNAPSE_URL
  synapse_prepare
)"
assert_eq "$got" "${clone_tmp}/home/synapse" "existing Corebrum Synapse checkout is reused"
if [[ -s "$clone_log" ]]; then
  echo "FAIL: an existing Corebrum Synapse checkout was cloned again" >&2
  exit 1
fi
assert_eq "$(cat "${clone_tmp}/home/synapse/marker")" "keep" "existing Corebrum Synapse checkout was replaced"

mkdir -p "${clone_tmp}/occupied"
: >"$clone_log"
if (
  export GIT_LOG="$clone_log"
  export PATH="${clone_bin}:/usr/bin:/bin"
  export COREBRUM_SYNAPSE_ROOT="${clone_tmp}/occupied"
  unset COREBRUM_SYNAPSE_URL
  synapse_prepare >/dev/null 2>"${clone_tmp}/occupied.err"
); then
  echo "FAIL: a non-clone path was accepted" >&2
  exit 1
fi
if ! grep -q 'exists but is not a clone' "${clone_tmp}/occupied.err"; then
  echo "FAIL: a non-clone path did not stop the install" >&2
  exit 1
fi
if [[ -s "$clone_log" ]]; then
  echo "FAIL: a non-clone path was overwritten" >&2
  exit 1
fi

: >"$clone_log"
if (
  export GIT_LOG="$clone_log"
  export GIT_MODE=blank
  export PATH="${clone_bin}:/usr/bin:/bin"
  export COREBRUM_SYNAPSE_ROOT="${clone_tmp}/blank"
  unset COREBRUM_SYNAPSE_URL
  synapse_prepare >/dev/null 2>"${clone_tmp}/blank.err"
); then
  echo "FAIL: a clone without pnpm-workspace.yaml was accepted" >&2
  exit 1
fi
if ! grep -q 'no pnpm-workspace.yaml' "${clone_tmp}/blank.err"; then
  echo "FAIL: a clone without pnpm-workspace.yaml did not stop the install" >&2
  exit 1
fi

home_clone="${clone_tmp}/desktop-home"
mkdir -p "$home_clone"
ln -s "${clone_tmp}/no-such/corebrum-os/scripts/corebrum.sh" "${clone_tmp}/bin/corebrum"
: >"$clone_log"
got="$(
  export GIT_LOG="$clone_log"
  export PATH="${clone_bin}:/usr/bin:/bin"
  export COREBRUM_BIN="${clone_tmp}/bin/corebrum"
  export HOME="$home_clone"
  unset COREBRUM_ROOT COREBRUM_SYNAPSE_ROOT COREBRUM_SYNAPSE_URL
  synapse_prepare 2>/dev/null
)"
assert_eq "$got" "${home_clone}/synapse" "an unreachable Corebrum checkout clones Corebrum Synapse into the home directory"
if ! grep -qF "clone --depth 1 https://github.com/Corebrum/corebrum-synapse.git ${home_clone}/synapse" "$clone_log"; then
  echo "FAIL: home fallback did not clone https://github.com/Corebrum/corebrum-synapse.git" >&2
  printf '%s\n' "$(cat "$clone_log")" >&2
  exit 1
fi

dev_checkout="${clone_tmp}/dev/corebrum-os"
mkdir -p "${dev_checkout}/scripts" "${clone_tmp}/dev-home"
touch "${dev_checkout}/scripts/corebrum.sh"
ln -s "${dev_checkout}/scripts/corebrum.sh" "${clone_tmp}/bin/corebrum-dev"
: >"$clone_log"
got="$(
  export GIT_LOG="$clone_log"
  export PATH="${clone_bin}:/usr/bin:/bin"
  export COREBRUM_BIN="${clone_tmp}/bin/corebrum-dev"
  export HOME="${clone_tmp}/dev-home"
  unset COREBRUM_ROOT COREBRUM_SYNAPSE_ROOT COREBRUM_SYNAPSE_URL
  synapse_prepare 2>/dev/null
)"
assert_eq "$got" "${clone_tmp}/dev/synapse" "a writable sibling stays the Corebrum Synapse clone path"
rm -rf "$clone_tmp"

export COREBRUM_SYNAPSE_READY=1
assert_eq "$("$menu" entry-name)" "Corebrum Synapse" "initialized Corebrum Synapse has no install indicator"
"$menu" refresh
if ! grep -q '^Name=Corebrum Synapse$' "${runtime}/corebrum/applications/corebrum-synapse.desktop"; then
  echo "FAIL: refreshed desktop entry did not name Corebrum Synapse" >&2
  exit 1
fi
if ! grep -q '^Icon=/usr/share/corebrum/icon.png$' "${runtime}/corebrum/applications/corebrum-synapse.desktop"; then
  echo "FAIL: the Corebrum Synapse menu row does not use the Corebrum Synapse mark" >&2
  exit 1
fi
motors_entry="${runtime}/corebrum/applications/corebrum-synapse-action-motors-start.desktop"
if ! grep -q '^Name=Motors: Start$' "$motors_entry"; then
  echo "FAIL: Super+Space does not list Motors: Start for search" >&2
  exit 1
fi
if ! grep -q '^Exec=/usr/local/bin/corebrum-synapse-menu launch motors-start$' "$motors_entry"; then
  echo "FAIL: choosing Motors: Start from search does not run that action" >&2
  exit 1
fi
if ! grep -q '^NoDisplay=true$' "$motors_entry"; then
  echo "FAIL: Motors: Start is listed in the idle Super+Space menu" >&2
  exit 1
fi
assert_eq "$("$menu" launch arc-connect)" "synapse connect" "typing arc connect uses the CLI"
export COREBRUM_SYNAPSE_CHOICE="Cloud: Connect"
assert_eq "$("$menu" open)" "synapse connect" "ARC connect uses the CLI"
export COREBRUM_SYNAPSE_CHOICE="Camera: Start RealSense"
assert_eq "$("$menu" open)" "synapse start realsense" "RealSense start uses the CLI"
export COREBRUM_SYNAPSE_CHOICE="Stack: Real robot"
assert_eq "$("$menu" open)" "synapse up real" "real robot uses synapse up"
export COREBRUM_SYNAPSE_CHOICE="Eyes: Stop"
assert_eq "$("$menu" open)" "synapse stop eyes" "eyes stop uses the CLI"
export COREBRUM_SYNAPSE_CHOICE="Agents: Connect installed CLIs"
assert_eq "$("$menu" open)" "synapse mcp setup --installed" "agent connect refreshes MCP setup"

export COREBRUM_SYNAPSE_STATUS_JSON='{"hardware":[{"name":"comms","running":true},{"name":"realsense","running":false}],"components":[{"name":"eyes","running":false}],"openclawGatewayActive":false}'
shown="$("$status" show)"
if ! grep -q '"class": "connected"' <<<"$shown"; then
  echo "FAIL: connected Cloud did not mark the status connected" >&2
  printf '%s\n' "$shown" >&2
  exit 1
fi
if ! grep -q 'realsense: stopped' <<<"$shown"; then
  echo "FAIL: status tooltip omitted RealSense" >&2
  exit 1
fi
export COREBRUM_SYNAPSE_STATUS_JSON='{"absent":true}'
shown="$("$status" show)"
if ! grep -q '"class": "absent"' <<<"$shown"; then
  echo "FAIL: missing CLI did not hide the status text" >&2
  exit 1
fi
rm -rf "$runtime"

echo "ok: synapse-menu"
