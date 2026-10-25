#!/usr/bin/env bash
# Clone AgenticROS when this machine has no checkout, build it, and link
# /usr/local/bin/agenticros.
set -euo pipefail

# Missing checkouts are cloned from this URL. An existing workspace is left in place.
COREBRUM_AGENTICROS_URL="${COREBRUM_AGENTICROS_URL:-https://github.com/agenticros/agenticros.git}"

corebrum_agenticros_install_die() {
  printf 'corebrum-agenticros-install: %s\n' "$1" >&2
  exit 1
}

corebrum_agenticros_checkout() {
  local bin resolved
  if [[ -n "${COREBRUM_ROOT:-}" && -f "${COREBRUM_ROOT}/scripts/corebrum.sh" ]]; then
    printf '%s\n' "$COREBRUM_ROOT"
    return 0
  fi
  bin="${COREBRUM_BIN:-/usr/local/bin/corebrum}"
  if [[ -e "$bin" ]]; then
    resolved="$(readlink -f "$bin")"
    dirname "$(dirname "$resolved")"
    return 0
  fi
  cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd
}

corebrum_agenticros_clone() {
  local checkout
  if [[ -n "${COREBRUM_AGENTICROS_ROOT:-}" ]]; then
    printf '%s\n' "$COREBRUM_AGENTICROS_ROOT"
    return 0
  fi
  checkout="$(corebrum_agenticros_checkout)"
  printf '%s\n' "$(cd "$(dirname "$checkout")" && pwd)/agenticros"
}

corebrum_agenticros_ensure_git() {
  if command -v git >/dev/null 2>&1; then
    return 0
  fi
  printf 'Installing git\n'
  sudo DEBIAN_FRONTEND=noninteractive apt-get update
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends git
  command -v git >/dev/null 2>&1 || corebrum_agenticros_install_die "git is not installed"
}

# Print the checkout path. An existing workspace is left in place. A missing
# directory is cloned. A path that exists without the workspace file is left
# untouched and the install stops.
corebrum_agenticros_prepare_clone() {
  local root parent
  root="$(corebrum_agenticros_clone)"
  if [[ -f "${root}/pnpm-workspace.yaml" ]]; then
    printf '%s\n' "$root"
    return 0
  fi
  if [[ -e "$root" ]]; then
    corebrum_agenticros_install_die "AgenticROS path exists but is not a clone: ${root}"
  fi
  parent="$(dirname "$root")"
  if [[ ! -d "$parent" || ! -w "$parent" ]]; then
    corebrum_agenticros_install_die "cannot clone AgenticROS into ${root}"
  fi
  corebrum_agenticros_ensure_git
  printf 'Cloning AgenticROS into %s\n' "$root" >&2
  GIT_TERMINAL_PROMPT=0 git clone --depth 1 "$COREBRUM_AGENTICROS_URL" "$root" \
    || corebrum_agenticros_install_die "could not clone ${COREBRUM_AGENTICROS_URL}"
  if [[ ! -f "${root}/pnpm-workspace.yaml" ]]; then
    corebrum_agenticros_install_die "cloned AgenticROS has no pnpm-workspace.yaml at ${root}"
  fi
  printf '%s\n' "$root"
}

corebrum_agenticros_pkg_installed() {
  local status
  status="$(dpkg-query -W -f='${Status}' "$1" 2>/dev/null || true)"
  [[ "$status" == "install ok installed" ]]
}

# rclnodejs compiles from source on Lyrical. A fresh Ubuntu install has Python
# from the ROS packages, and it does not have g++ or make until this step.
corebrum_agenticros_ensure_toolchain() {
  local missing=() pkg
  for pkg in build-essential python3; do
    if ! corebrum_agenticros_pkg_installed "$pkg"; then
      missing+=("$pkg")
    fi
  done
  [[ ${#missing[@]} -eq 0 ]] && return 0
  printf 'Installing %s\n' "${missing[*]}"
  sudo DEBIAN_FRONTEND=noninteractive apt-get update
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "${missing[@]}"
}

corebrum_agenticros_node_gyp() {
  local node_bin prefix
  node_bin="$(readlink -f "$(command -v node)")"
  prefix="$(dirname "$(dirname "$node_bin")")"
  printf '%s\n' "${prefix}/lib/node_modules/npm/node_modules/node-gyp/bin/node-gyp.js"
}

# rclnodejs has no Lyrical prebuilt. Its own install script uses a node-gyp
# that does not finish on this Node, so the native build runs after ROS is
# sourced and with the node-gyp shipped beside npm.
corebrum_agenticros_build_rclnodejs() {
  local ros_setup="" distro gyp rcl
  if [[ -f /etc/corebrum/ros/distro ]]; then
    distro="$(tr -d '[:space:]' < /etc/corebrum/ros/distro)"
    if [[ -f "/opt/ros/${distro}/setup.bash" ]]; then
      ros_setup="/opt/ros/${distro}/setup.bash"
    fi
  fi
  if [[ -z "$ros_setup" ]]; then
    for ros_setup in /opt/ros/*/setup.bash; do
      [[ -f "$ros_setup" ]] && break
      ros_setup=""
    done
  fi
  [[ -n "$ros_setup" ]] || return 0
  if [[ -e "$root/packages/core/node_modules/rclnodejs/package.json" ]]; then
    rcl="$(readlink -f "$root/packages/core/node_modules/rclnodejs/package.json")"
  else
    rcl="$(find "$root/node_modules/.pnpm" -path '*/node_modules/rclnodejs/package.json' -print -quit)"
  fi
  [[ -n "$rcl" ]] || return 0
  gyp="$(corebrum_agenticros_node_gyp)"
  [[ -f "$gyp" ]] || corebrum_agenticros_install_die "node-gyp not found at ${gyp}"
  printf 'Building rclnodejs against %s\n' "$ros_setup"
  (
    set +u
    # shellcheck disable=SC1090
    source "$ros_setup"
    export npm_config_yes=true
    cd "$(dirname "$rcl")"
    node "$gyp" -j "$(nproc)" rebuild
    node scripts/generate_messages.js
  )
}

corebrum_agenticros_install_main() {
root="$(corebrum_agenticros_prepare_clone)"

if [[ -f /etc/profile.d/corebrum-node.sh ]]; then
  # shellcheck disable=SC1091
  source /etc/profile.d/corebrum-node.sh
fi
command -v pnpm >/dev/null 2>&1 || corebrum_agenticros_install_die "pnpm is not installed"
command -v node >/dev/null 2>&1 || corebrum_agenticros_install_die "node is not installed"

corebrum_agenticros_ensure_toolchain

printf 'Building AgenticROS at %s\n' "$root"
(
  cd "$root"
  pnpm install --ignore-scripts
  pnpm -r build
)
corebrum_agenticros_build_rclnodejs

helper_src="$(corebrum_agenticros_checkout)/scripts/desktop/corebrum-agenticros-with-ros.sh"
if [[ ! -x /usr/local/lib/corebrum/agenticros-with-ros.sh ]]; then
  [[ -f "$helper_src" ]] || corebrum_agenticros_install_die "missing ${helper_src}"
  sudo install -d /usr/local/lib/corebrum
  sudo install -m 755 "$helper_src" /usr/local/lib/corebrum/agenticros-with-ros.sh
fi

wrapper="$(mktemp)"
cat >"$wrapper" <<'EOF'
#!/bin/bash
set -euo pipefail
if [[ -f /etc/profile.d/corebrum-node.sh ]]; then
  # shellcheck disable=SC1091
  source /etc/profile.d/corebrum-node.sh || true
fi
root="$(tr -d '[:space:]' < /etc/corebrum/agenticros.root)"
exec /usr/local/lib/corebrum/agenticros-with-ros.sh node "$root/packages/agenticros-cli/dist/index.js" "$@"
EOF
sudo install -d /etc/corebrum /usr/local/bin
printf '%s\n' "$root" | sudo tee /etc/corebrum/agenticros.root >/dev/null
sudo install -m 755 "$wrapper" /usr/local/bin/agenticros
rm -f "$wrapper"
printf 'AgenticROS CLI is linked at /usr/local/bin/agenticros\n'
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  corebrum_agenticros_install_main
fi
