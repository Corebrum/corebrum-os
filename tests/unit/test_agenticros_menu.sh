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
if ! grep -q 'prebuild-install' "$install_script" || ! grep -q 'node-datachannel' "$install_script"; then
  echo "FAIL: AgenticROS install does not install the node-datachannel prebuild" >&2
  exit 1
fi
if ! grep -q 'https://github.com/agenticros/agenticros.git' "$install_script"; then
  echo "FAIL: AgenticROS install does not clone github.com/agenticros/agenticros" >&2
  exit 1
fi

agenticros_prepare() {
  bash --noprofile --norc -c '
set -euo pipefail
source "$1"
corebrum_agenticros_prepare_clone
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
  unset COREBRUM_AGENTICROS_ROOT COREBRUM_AGENTICROS_URL
  agenticros_prepare 2>/dev/null
)"
assert_eq "$got" "${clone_tmp}/home/agenticros" "missing AgenticROS is cloned beside the Corebrum checkout"
if ! grep -qF "clone --depth 1 https://github.com/agenticros/agenticros.git ${clone_tmp}/home/agenticros" "$clone_log"; then
  echo "FAIL: clone did not use https://github.com/agenticros/agenticros.git" >&2
  printf '%s\n' "$(cat "$clone_log")" >&2
  exit 1
fi
printf 'keep\n' >"${clone_tmp}/home/agenticros/marker"
: >"$clone_log"
got="$(
  export GIT_LOG="$clone_log"
  export PATH="${clone_bin}:/usr/bin:/bin"
  export COREBRUM_AGENTICROS_ROOT="${clone_tmp}/home/agenticros"
  unset COREBRUM_AGENTICROS_URL
  agenticros_prepare
)"
assert_eq "$got" "${clone_tmp}/home/agenticros" "existing AgenticROS checkout is reused"
if [[ -s "$clone_log" ]]; then
  echo "FAIL: an existing AgenticROS checkout was cloned again" >&2
  exit 1
fi
assert_eq "$(cat "${clone_tmp}/home/agenticros/marker")" "keep" "existing AgenticROS checkout was replaced"

mkdir -p "${clone_tmp}/occupied"
: >"$clone_log"
if (
  export GIT_LOG="$clone_log"
  export PATH="${clone_bin}:/usr/bin:/bin"
  export COREBRUM_AGENTICROS_ROOT="${clone_tmp}/occupied"
  unset COREBRUM_AGENTICROS_URL
  agenticros_prepare >/dev/null 2>"${clone_tmp}/occupied.err"
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
  export COREBRUM_AGENTICROS_ROOT="${clone_tmp}/blank"
  unset COREBRUM_AGENTICROS_URL
  agenticros_prepare >/dev/null 2>"${clone_tmp}/blank.err"
); then
  echo "FAIL: a clone without pnpm-workspace.yaml was accepted" >&2
  exit 1
fi
if ! grep -q 'no pnpm-workspace.yaml' "${clone_tmp}/blank.err"; then
  echo "FAIL: a clone without pnpm-workspace.yaml did not stop the install" >&2
  exit 1
fi
rm -rf "$clone_tmp"

export COREBRUM_AGENTICROS_READY=1
assert_eq "$("$menu" entry-name)" "AgenticROS" "initialized AgenticROS has no install indicator"
"$menu" refresh
if ! grep -q '^Name=AgenticROS$' "${runtime}/corebrum/applications/corebrum-agenticros.desktop"; then
  echo "FAIL: refreshed desktop entry did not name AgenticROS" >&2
  exit 1
fi
if ! grep -q '^Icon=/usr/share/corebrum/agenticros.png$' "${runtime}/corebrum/applications/corebrum-agenticros.desktop"; then
  echo "FAIL: the AgenticROS menu row does not use the AgenticROS mark" >&2
  exit 1
fi
motors_entry="${runtime}/corebrum/applications/corebrum-agenticros-action-motors-start.desktop"
if ! grep -q '^Name=Motors: Start$' "$motors_entry"; then
  echo "FAIL: Super+Space does not list Motors: Start for search" >&2
  exit 1
fi
if ! grep -q '^Exec=/usr/local/bin/corebrum-agenticros-menu launch motors-start$' "$motors_entry"; then
  echo "FAIL: choosing Motors: Start from search does not run that action" >&2
  exit 1
fi
if ! grep -q '^NoDisplay=true$' "$motors_entry"; then
  echo "FAIL: Motors: Start is listed in the idle Super+Space menu" >&2
  exit 1
fi
assert_eq "$("$menu" launch arc-connect)" "agenticros connect" "typing arc connect uses the CLI"
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
