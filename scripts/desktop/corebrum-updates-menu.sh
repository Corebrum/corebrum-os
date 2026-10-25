#!/usr/bin/env bash
# Super+Space Updates. Each row runs in a terminal. Nothing here starts on its own.
set -euo pipefail

corebrum_updates_die() {
  printf 'corebrum-updates-menu: %s\n' "$1" >&2
  exit 1
}

corebrum_updates_data_dir() {
  local root="${XDG_RUNTIME_DIR:-/tmp/corebrum-launcher-${UID}}"
  printf '%s\n' "${root}/corebrum"
}

corebrum_updates_stamp() {
  local root="${XDG_STATE_HOME:-${HOME}/.local/state}"
  printf '%s\n' "${root}/corebrum/updates-reminded"
}

corebrum_updates_repo() {
  local here resolved
  if [[ -n "${COREBRUM_UPDATES_ROOT:-}" && -f "${COREBRUM_UPDATES_ROOT}/scripts/lib/ros.sh" ]]; then
    printf '%s\n' "$COREBRUM_UPDATES_ROOT"
    return 0
  fi
  here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  if [[ -f "${here}/../lib/ros.sh" ]]; then
    (cd "${here}/../.." && pwd)
    return 0
  fi
  if [[ -e /usr/local/bin/corebrum ]]; then
    resolved="$(readlink -f /usr/local/bin/corebrum)"
    here="$(dirname "$(dirname "$resolved")")"
    if [[ -f "${here}/scripts/lib/ros.sh" ]]; then
      printf '%s\n' "$here"
      return 0
    fi
  fi
  return 1
}

corebrum_updates_corebrum_root() {
  local resolved
  if [[ -n "${COREBRUM_UPDATES_ROOT:-}" ]]; then
    printf '%s\n' "$COREBRUM_UPDATES_ROOT"
    return 0
  fi
  if [[ "${COREBRUM_UPDATES_STUB:-0}" == 1 ]]; then
    printf 'checkout\n'
    return 0
  fi
  if [[ ! -e /usr/local/bin/corebrum ]]; then
    return 1
  fi
  resolved="$(readlink -f /usr/local/bin/corebrum)"
  dirname "$(dirname "$resolved")"
}

corebrum_updates_agenticros_root() {
  local root
  if [[ -n "${COREBRUM_UPDATES_AGENTICROS_ROOT:-}" ]]; then
    printf '%s\n' "$COREBRUM_UPDATES_AGENTICROS_ROOT"
    return 0
  fi
  if [[ "${COREBRUM_UPDATES_STUB:-0}" == 1 ]]; then
    printf 'agenticros\n'
    return 0
  fi
  [[ -s /etc/corebrum/agenticros.root ]] || return 1
  root="$(tr -d '[:space:]' </etc/corebrum/agenticros.root)"
  [[ -n "$root" ]] || return 1
  printf '%s\n' "$root"
}

corebrum_updates_tool() {
  local override="$1" script="$2" installed="$3" here
  if [[ -n "$override" ]]; then
    printf '%s\n' "$override"
    return 0
  fi
  here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  if [[ -f "${here}/${script}" ]]; then
    printf '%s\n' "${here}/${script}"
    return 0
  fi
  printf '%s\n' "$installed"
}

corebrum_updates_ros_ready() {
  local distro status
  if [[ "${COREBRUM_UPDATES_STUB:-0}" == 1 ]]; then
    [[ "${COREBRUM_UPDATES_ROS:-0}" == 1 ]]
    return
  fi
  [[ -f /etc/corebrum/ros/distro ]] || return 1
  distro="$(tr -d '[:space:]' </etc/corebrum/ros/distro)"
  [[ -n "$distro" ]] || return 1
  status="$(dpkg-query -W -f='${Status}' "ros-${distro}-ros-base" 2>/dev/null || true)"
  [[ "$status" == "install ok installed" ]]
}

corebrum_updates_agenticros_ready() {
  if [[ "${COREBRUM_UPDATES_STUB:-0}" == 1 ]]; then
    [[ "${COREBRUM_UPDATES_AGENTICROS:-0}" == 1 ]]
    return
  fi
  [[ -s /etc/corebrum/agenticros.root && -x /usr/local/bin/agenticros ]]
}

corebrum_updates_fleet_ready() {
  if [[ "${COREBRUM_UPDATES_STUB:-0}" == 1 ]]; then
    [[ "${COREBRUM_UPDATES_ZENOH_FLEET:-0}" == 1 ]]
    return
  fi
  command -v zenoh-fleet >/dev/null 2>&1
}

# .mcp.json is tracked with a relative command. agenticros mcp setup, which
# init runs, rewrites it with this machine's ROS wrapper. That is not an edit
# the operator made.
corebrum_updates_generated_path() {
  local name="$1" line="$2" path
  [[ "$name" == agenticros ]] || return 1
  path="${line:3}"
  [[ "$path" == ".mcp.json" ]]
}

corebrum_updates_git_dirty() {
  local name="$1" root="$2" status line
  if [[ "${COREBRUM_UPDATES_STUB:-0}" == 1 ]]; then
    [[ "${COREBRUM_UPDATES_DIRTY:-}" == "$name" ]]
    return
  fi
  status="$(git -C "$root" status --porcelain --untracked-files=no)" || return 0
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    corebrum_updates_generated_path "$name" "$line" && continue
    return 0
  done <<< "$status"
  return 1
}

corebrum_updates_restore_agenticros_mcp() {
  local root="$1"
  if [[ "${COREBRUM_UPDATES_STUB:-0}" == 1 ]]; then
    printf 'run: git -C %s checkout -- .mcp.json\n' "$root"
    return 0
  fi
  if [[ -n "$(git -C "$root" status --porcelain --untracked-files=no -- .mcp.json)" ]]; then
    printf 'Restoring .mcp.json. MCP setup writes this machine'\''s ROS wrapper there, and init writes it again.\n'
    git -C "$root" checkout -- .mcp.json
  fi
}

corebrum_updates_run() {
  if [[ "${COREBRUM_UPDATES_STUB:-0}" == 1 ]]; then
    printf 'run: %s\n' "$*"
    return 0
  fi
  "$@"
}

corebrum_updates_pin() {
  local file="$1" var="$2" value
  value="$(sed -n "s/^${var}=\"\\(.*\\)\"/\\1/p" "$file")"
  [[ -n "$value" ]] || corebrum_updates_die "missing ${var} in ${file}"
  printf '%s\n' "$value"
}

corebrum_updates_labels() {
  printf '%s\n' \
    Ubuntu \
    Corebrum \
    "ROS 2" \
    Zenoh \
    AgenticROS \
    "AI Agents" \
    All
}

corebrum_updates_refresh() {
  local dir
  dir="$(corebrum_updates_data_dir)/applications"
  mkdir -p "$dir"
  cat >"${dir}/corebrum-updates.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=Updates
GenericName=Updates
Comment=Upgrade Ubuntu, Corebrum, ROS 2, Zenoh, AgenticROS, and installed AI agents
Keywords=update;upgrade;apt;ubuntu;ros;zenoh;agenticros
Exec=/usr/local/bin/corebrum-updates-menu open
Icon=system-software-update
Terminal=false
Categories=System;
StartupNotify=false
EOF
}

corebrum_updates_apply_ubuntu() {
  printf '== Ubuntu ==\n'
  corebrum_updates_run sudo DEBIAN_FRONTEND=noninteractive apt-get update
  corebrum_updates_run sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y
}

corebrum_updates_apply_corebrum() {
  local root
  printf '== Corebrum ==\n'
  root="$(corebrum_updates_corebrum_root)" || corebrum_updates_die "cannot find the Corebrum checkout from /usr/local/bin/corebrum"
  if [[ "${COREBRUM_UPDATES_STUB:-0}" != 1 ]]; then
    git -C "$root" rev-parse --is-inside-work-tree >/dev/null 2>&1 \
      || corebrum_updates_die "Corebrum checkout is not a git work tree (${root})"
  fi
  if corebrum_updates_git_dirty corebrum "$root"; then
    corebrum_updates_die "Corebrum checkout has local changes (${root}). Update stopped."
  fi
  corebrum_updates_run git -C "$root" pull --ff-only
  corebrum_updates_run sudo corebrum install desktop
  printf 'Log out so the session reloads the copied Hyprland config.\n'
}

corebrum_updates_apply_ros() {
  local distro pkgs
  printf '== ROS 2 ==\n'
  if ! corebrum_updates_ros_ready; then
    printf 'ROS 2 is not installed. Skipped.\n'
    return 0
  fi
  corebrum_updates_run sudo corebrum install ros
  if [[ "${COREBRUM_UPDATES_STUB:-0}" == 1 ]]; then
    printf 'run: sudo DEBIAN_FRONTEND=noninteractive apt-get install -y --only-upgrade ros-<distro>-*\n'
    return 0
  fi
  distro="$(tr -d '[:space:]' </etc/corebrum/ros/distro)"
  mapfile -t pkgs < <(dpkg-query -W -f '${Package}\n' | grep -E "^ros-${distro}-" || true)
  if [[ "${#pkgs[@]}" -gt 0 ]]; then
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y --only-upgrade "${pkgs[@]}"
  fi
}

corebrum_updates_apply_zenoh() {
  local repo ros_lib lib tool fleet_menu line
  printf '== Zenoh ==\n'
  if corebrum_updates_ros_ready; then
    repo="$(corebrum_updates_repo)" || corebrum_updates_die "cannot find scripts/lib/ros.sh"
    ros_lib="${repo}/scripts/lib/ros.sh"
    lib="$(corebrum_updates_pin "$ros_lib" COREBRUM_ZENOH_CLI_LIB)"
    tool="$(corebrum_updates_pin "$ros_lib" COREBRUM_ZENOH_CLI_TOOL)"
    if [[ "${COREBRUM_UPDATES_STUB:-0}" != 1 && ! -x /opt/corebrum/zenoh-cli/bin/pip ]]; then
      corebrum_updates_die "the Zenoh client is not installed at /opt/corebrum/zenoh-cli"
    fi
    corebrum_updates_run sudo /opt/corebrum/zenoh-cli/bin/pip install --disable-pip-version-check "$lib" "$tool"
    corebrum_updates_run sudo install -m 755 "${repo}/scripts/ros/zenoh-cli.sh" /usr/local/bin/zenoh
  else
    printf 'ROS 2 is not installed, so the Zenoh client stays as it is.\n'
  fi
  if corebrum_updates_fleet_ready; then
    fleet_menu="$(corebrum_updates_tool "${COREBRUM_UPDATES_FLEET_MENU:-}" corebrum-zenoh-fleet-menu.sh /usr/local/bin/corebrum-zenoh-fleet-menu)"
    if [[ "${COREBRUM_UPDATES_STUB:-0}" == 1 ]]; then
      line="$(COREBRUM_ZENOH_FLEET_STUB=1 "$fleet_menu" command)"
      printf 'run: %s\n' "$line"
    else
      line="$("$fleet_menu" command)"
      bash -c "$line"
    fi
  else
    printf 'Zenoh fleet is not installed. Skipped.\n'
  fi
}

corebrum_updates_apply_agenticros() {
  local root script
  printf '== AgenticROS ==\n'
  if ! corebrum_updates_agenticros_ready; then
    printf 'AgenticROS is not installed. Skipped.\n'
    return 0
  fi
  root="$(corebrum_updates_agenticros_root)" || corebrum_updates_die "AgenticROS checkout is not recorded"
  if corebrum_updates_git_dirty agenticros "$root"; then
    corebrum_updates_die "AgenticROS checkout has local changes (${root}). Update stopped."
  fi
  corebrum_updates_restore_agenticros_mcp "$root"
  if [[ "${COREBRUM_UPDATES_STUB:-0}" == 1 ]]; then
    printf 'run: git -C %s fetch --depth 1 origin main\n' "$root"
    printf 'run: git -C %s merge --ff-only FETCH_HEAD\n' "$root"
    printf 'run: agenticros-install.sh\n'
    printf 'run: agenticros init --yes\n'
    return 0
  fi
  git -C "$root" fetch --depth 1 origin main
  git -C "$root" merge --ff-only FETCH_HEAD
  if [[ -n "${COREBRUM_UPDATES_AGENTICROS_INSTALL:-}" ]]; then
    script="$COREBRUM_UPDATES_AGENTICROS_INSTALL"
  elif [[ -x /usr/local/lib/corebrum/agenticros-install.sh ]]; then
    script=/usr/local/lib/corebrum/agenticros-install.sh
  else
    script="$(corebrum_updates_repo)/scripts/desktop/corebrum-agenticros-install.sh"
  fi
  "$script"
  /usr/local/bin/agenticros init --yes
}

corebrum_updates_apply_agents() {
  local menu
  printf '== AI Agents ==\n'
  menu="$(corebrum_updates_tool "${COREBRUM_UPDATES_AGENTS_MENU:-}" corebrum-agents-menu.sh /usr/local/bin/corebrum-agents-menu)"
  if [[ "${COREBRUM_UPDATES_STUB:-0}" == 1 ]]; then
    COREBRUM_AGENTS_STUB=1 \
      COREBRUM_AGENTICROS_READY="${COREBRUM_UPDATES_AGENTICROS:-0}" \
      "$menu" update-installed
    return 0
  fi
  "$menu" update-installed
}

corebrum_updates_apply_all() {
  corebrum_updates_apply_ubuntu
  corebrum_updates_apply_corebrum
  corebrum_updates_apply_ros
  corebrum_updates_apply_zenoh
  corebrum_updates_apply_agenticros
  corebrum_updates_apply_agents
}

corebrum_updates_note_reboot() {
  if [[ "${COREBRUM_UPDATES_STUB:-0}" == 1 ]]; then
    if [[ "${COREBRUM_UPDATES_REBOOT:-0}" == 1 ]]; then
      printf 'A reboot is required before the new packages are fully in use.\n'
    fi
    return 0
  fi
  return 0
}

corebrum_updates_apply() {
  local choice="$1"
  case "$choice" in
    ubuntu | Ubuntu) corebrum_updates_apply_ubuntu ;;
    corebrum | Corebrum) corebrum_updates_apply_corebrum ;;
    ros | ROS | "ROS 2") corebrum_updates_apply_ros ;;
    zenoh | Zenoh) corebrum_updates_apply_zenoh ;;
    agenticros | AgenticROS) corebrum_updates_apply_agenticros ;;
    agents | "AI Agents") corebrum_updates_apply_agents ;;
    all | All) corebrum_updates_apply_all ;;
    *)
      corebrum_updates_die "unknown update: ${choice}"
      ;;
  esac
  corebrum_updates_note_reboot
}

corebrum_updates_terminal() {
  local choice="$1" self
  self="$(readlink -f "${BASH_SOURCE[0]}")"
  exec /usr/local/bin/corebrum-terminal bash -c "$(cat <<EOF
set +e
$(printf '%q' "$self") apply $(printf '%q' "$choice")
ec=\$?
set -e
if [ -e /var/run/reboot-required ]; then
  printf '%s\n' "A reboot is required before the new packages are fully in use."
fi
printf '\n'
if [ "\$ec" -ne 0 ]; then
  printf 'Update failed (%s).\n' "\$ec"
fi
read -r -p 'Press Enter to close. '
exit "\$ec"
EOF
)"
}

corebrum_updates_open() {
  local choice
  if [[ "${COREBRUM_UPDATES_STUB:-0}" == 1 ]]; then
    choice="${COREBRUM_UPDATES_CHOICE:-}"
    if [[ -z "$choice" ]]; then
      corebrum_updates_labels
      return 0
    fi
    corebrum_updates_apply "$choice"
    return 0
  fi
  choice="$(corebrum_updates_labels | fuzzel \
    --config /etc/corebrum/fuzzel/fuzzel.ini \
    --dmenu \
    --prompt 'Updates  ' \
    --width 40 \
    --lines 8)" || return 0
  [[ -n "$choice" ]] || return 0
  corebrum_updates_terminal "$choice"
}

# Login reminder. It does not run apt or git.
corebrum_updates_remind() {
  local stamp now then age
  stamp="$(corebrum_updates_stamp)"
  now="$(date +%s)"
  if [[ -f "$stamp" ]]; then
    then="$(stat -c %Y "$stamp")"
    age=$((now - then))
    if ((age >= 0 && age < 604800)); then
      return 0
    fi
  fi
  mkdir -p "$(dirname "$stamp")"
  touch "$stamp"
  if [[ "${COREBRUM_UPDATES_STUB:-0}" == 1 ]]; then
    printf 'notify-send Updates\n'
    return 0
  fi
  if command -v notify-send >/dev/null 2>&1; then
    notify-send "Updates" "Open Super+Space and choose Updates."
  fi
}

usage() {
  cat <<'EOF'
Usage: corebrum-updates-menu refresh|open|labels|apply NAME|remind|data-dir
EOF
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
cmd="${1:-}"
case "$cmd" in
  refresh) corebrum_updates_refresh ;;
  open) corebrum_updates_open ;;
  labels) corebrum_updates_labels ;;
  apply) corebrum_updates_apply "${2:-}" ;;
  remind) corebrum_updates_remind ;;
  data-dir) corebrum_updates_data_dir ;;
  -h | --help | help) usage ;;
  *)
    usage >&2
    exit 1
    ;;
esac
fi
