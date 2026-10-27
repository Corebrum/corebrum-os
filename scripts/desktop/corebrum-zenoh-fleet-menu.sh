#!/usr/bin/env bash
# Super+Space Zenoh fleet entry. Install the config wizard, or run it.
set -euo pipefail

COREBRUM_ZENOH_FLEET_INSTALL_MARK='   install'
COREBRUM_ZENOH_FLEET_PACKAGE='@agenticros/zenoh-fleet@0.1.4'
COREBRUM_ZENOH_FLEET_ALLOW='@agenticros/zenoh-fleet'

corebrum_zenoh_fleet_prepare_path() {
  local here helper
  if [[ "${COREBRUM_ZENOH_FLEET_STUB:-0}" == 1 ]]; then
    return 0
  fi
  here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  if [[ -f "${here}/corebrum-node-path.sh" ]]; then
    helper="${here}/corebrum-node-path.sh"
  else
    helper=/usr/local/lib/corebrum/node-path.sh
  fi
  if [[ -f "$helper" ]]; then
    # shellcheck disable=SC1090
    source "$helper"
    corebrum_node_prepare_path
  fi
}

corebrum_zenoh_fleet_ready() {
  if [[ "${COREBRUM_ZENOH_FLEET_STUB:-0}" == 1 ]]; then
    [[ "${COREBRUM_ZENOH_FLEET_READY:-0}" == 1 ]]
    return
  fi
  corebrum_zenoh_fleet_prepare_path
  command -v zenoh-fleet >/dev/null 2>&1
}

corebrum_zenoh_fleet_entry_name() {
  if corebrum_zenoh_fleet_ready; then
    printf 'Zenoh fleet\n'
  else
    printf 'Zenoh fleet%s\n' "$COREBRUM_ZENOH_FLEET_INSTALL_MARK"
  fi
}

corebrum_zenoh_fleet_data_dir() {
  local root="${XDG_RUNTIME_DIR:-/tmp/corebrum-launcher-${UID}}"
  printf '%s\n' "${root}/corebrum"
}

corebrum_zenoh_fleet_refresh() {
  local dir name
  dir="$(corebrum_zenoh_fleet_data_dir)/applications"
  name="$(corebrum_zenoh_fleet_entry_name)"
  mkdir -p "$dir"
  cat >"${dir}/corebrum-zenoh-fleet.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=${name}
GenericName=${name}
Comment=Configure a Zenoh fleet hub or member
Keywords=zenoh;fleet;config
Exec=/usr/local/bin/corebrum-zenoh-fleet-menu open
Icon=/usr/share/corebrum/zenoh.png
Terminal=false
Categories=Science;Network;
StartupNotify=false
EOF
}

corebrum_zenoh_fleet_terminal() {
  local script="$1"
  if [[ "${COREBRUM_ZENOH_FLEET_STUB:-0}" == 1 ]]; then
    printf '%s\n' "$script"
    return 0
  fi
  exec /usr/local/bin/corebrum-terminal bash -c "$script"
}

corebrum_zenoh_fleet_install_action() {
  local node_bin npm_bin node_dir path_value
  if [[ "${COREBRUM_ZENOH_FLEET_STUB:-0}" == 1 ]]; then
    printf 'sudo env PATH="$node_dir:$PATH" node npm install -g --allow-scripts=%s %s\n' \
      "$COREBRUM_ZENOH_FLEET_ALLOW" "$COREBRUM_ZENOH_FLEET_PACKAGE"
    return 0
  fi
  corebrum_zenoh_fleet_prepare_path
  node_bin="$(command -v node || true)"
  npm_bin="$(command -v npm || true)"
  if [[ -z "$node_bin" || ! -x "$node_bin" || -z "$npm_bin" || ! -x "$npm_bin" ]]; then
    printf 'Node.js from the desktop profile is required before Zenoh fleet can be installed.\n' >&2
    return 1
  fi
  node_dir="$(dirname "$node_bin")"
  path_value="${node_dir}:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
  printf 'sudo env PATH=%q %q %q install -g --allow-scripts=%q %q\n' \
    "$path_value" "$node_bin" "$npm_bin" "$COREBRUM_ZENOH_FLEET_ALLOW" "$COREBRUM_ZENOH_FLEET_PACKAGE"
}

corebrum_zenoh_fleet_install() {
  local node_bin npm_bin node_dir path_value action
  if [[ "${COREBRUM_ZENOH_FLEET_STUB:-0}" == 1 ]]; then
    printf 'sudo env PATH="$node_dir:$PATH" node npm install -g --allow-scripts=%s %s\n' \
      "$COREBRUM_ZENOH_FLEET_ALLOW" "$COREBRUM_ZENOH_FLEET_PACKAGE"
    return 0
  fi
  corebrum_zenoh_fleet_prepare_path
  node_bin="$(command -v node || true)"
  npm_bin="$(command -v npm || true)"
  if [[ -z "$node_bin" || ! -x "$node_bin" || -z "$npm_bin" || ! -x "$npm_bin" ]]; then
    corebrum_zenoh_fleet_terminal "$(cat <<'EOF'
printf '%s\n' "Node.js from the desktop profile is required before Zenoh fleet can be installed."
read -r -p 'Press Enter to close. '
EOF
)"
    return 0
  fi
  node_dir="$(dirname "$node_bin")"
  path_value="${node_dir}:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
  action="sudo env PATH=$(printf '%q' "$path_value") $(printf '%q' "$node_bin") $(printf '%q' "$npm_bin") install -g --allow-scripts=$(printf '%q' "$COREBRUM_ZENOH_FLEET_ALLOW") $(printf '%q' "$COREBRUM_ZENOH_FLEET_PACKAGE")"
  corebrum_zenoh_fleet_terminal "$(cat <<EOF
set +e
${action}
ec=\$?
set -e
printf '\n'
if [ "\$ec" -eq 0 ]; then
  printf '%s\n' "Zenoh fleet is installed. Press Super+Space and choose Zenoh fleet to run the wizard."
else
  printf 'Install failed (%s).\n' "\$ec"
fi
read -r -p 'Press Enter to close. '
EOF
)"
}

corebrum_zenoh_fleet_launch() {
  if [[ "${COREBRUM_ZENOH_FLEET_STUB:-0}" == 1 ]]; then
    printf 'zenoh-fleet\n'
    return 0
  fi
  corebrum_zenoh_fleet_terminal "$(cat <<'EOF'
set +e
cd "${HOME:-.}"
zenoh-fleet
ec=$?
set -e
printf '\n'
if [ "$ec" -ne 0 ]; then
  printf 'zenoh-fleet exited (%s).\n' "$ec"
fi
read -r -p 'Press Enter to close. '
EOF
)"
}

corebrum_zenoh_fleet_open() {
  if corebrum_zenoh_fleet_ready; then
    corebrum_zenoh_fleet_launch
    return 0
  fi
  corebrum_zenoh_fleet_install
}

usage() {
  cat <<'EOF'
Usage: corebrum-zenoh-fleet-menu refresh|open|command|entry-name|data-dir
EOF
}

cmd="${1:-}"
case "$cmd" in
  refresh) corebrum_zenoh_fleet_refresh ;;
  open) corebrum_zenoh_fleet_open ;;
  command) corebrum_zenoh_fleet_install_action ;;
  entry-name) corebrum_zenoh_fleet_entry_name ;;
  data-dir) corebrum_zenoh_fleet_data_dir ;;
  -h | --help | help) usage ;;
  *)
    usage >&2
    exit 1
    ;;
esac
