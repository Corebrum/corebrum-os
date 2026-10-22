#!/usr/bin/env bash
# Phase 4 command helpers. Source this file; do not execute it.
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  echo "source scripts/lib/cli.sh from another script" >&2
  exit 1
fi

# shellcheck source=files.sh
source "${COREBRUM_ROOT}/scripts/lib/files.sh"
# shellcheck source=system.sh
source "${COREBRUM_ROOT}/scripts/lib/system.sh"

COREBRUM_COMMAND_PATH="/usr/local/bin/corebrum"
COREBRUM_LAUNCHER_PATH="/usr/local/share/applications/corebrum-grid.desktop"

corebrum_version_string() {
  local version_file="${COREBRUM_ROOT}/VERSION"
  [[ -f "$version_file" ]] || corebrum_die "missing ${version_file}"
  tr -d '[:space:]' <"$version_file"
}

corebrum_pkg_installed() {
  local status
  status="$(dpkg-query -W -f='${Status}' "$1" 2>/dev/null || true)"
  [[ "$status" == "install ok installed" ]]
}

corebrum_install_command() {
  local src="${COREBRUM_ROOT}/scripts/corebrum.sh"
  local current=""
  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    corebrum_log "dry-run: link ${COREBRUM_COMMAND_PATH} to ${src}"
    return 0
  fi
  [[ -f "$src" ]] || corebrum_die "missing ${src}"
  if [[ -L "$COREBRUM_COMMAND_PATH" ]] && current="$(readlink -f "$COREBRUM_COMMAND_PATH")" && [[ "$current" == "$(readlink -f "$src")" ]]; then
    corebrum_log "unchanged: ${COREBRUM_COMMAND_PATH}"
    return 0
  fi
  mkdir -p "$(dirname "$COREBRUM_COMMAND_PATH")"
  if [[ -e "$COREBRUM_COMMAND_PATH" && ! -L "$COREBRUM_COMMAND_PATH" ]]; then
    corebrum_backup_file "$COREBRUM_COMMAND_PATH"
    rm -f "$COREBRUM_COMMAND_PATH"
  fi
  ln -sfn "$src" "$COREBRUM_COMMAND_PATH"
  corebrum_log "installed ${COREBRUM_COMMAND_PATH}"
}

corebrum_cmd_version() {
  printf 'corebrum %s\n' "$(corebrum_version_string)"
}

corebrum_profile_line() {
  local name="$1"
  local installed="$2"
  if [[ "$installed" -eq 1 ]]; then
    printf 'profile %s: installed\n' "$name"
  else
    printf 'profile %s: not installed\n' "$name"
  fi
}

corebrum_cmd_status() {
  local base=0 desktop=0 services=0 ros=0
  corebrum_cmd_version
  printf 'checkout: %s\n' "$COREBRUM_ROOT"
  if corebrum_pkg_installed ca-certificates && corebrum_pkg_installed systemd-timesyncd; then
    base=1
  fi
  if corebrum_pkg_installed hyprland && [[ -f /etc/corebrum/hypr/hyprland.conf ]]; then
    desktop=1
  fi
  if corebrum_pkg_installed network-manager && [[ -f /etc/xdg/xdg-desktop-portal/hyprland-portals.conf ]]; then
    services=1
  fi
  if { corebrum_pkg_installed ros-jazzy-ros-base || corebrum_pkg_installed ros-lyrical-ros-base; } && [[ -f /etc/corebrum/ros/rmw ]]; then
    ros=1
  fi
  corebrum_profile_line base "$base"
  corebrum_profile_line desktop "$desktop"
  corebrum_profile_line services "$services"
  corebrum_profile_line ros "$ros"
  if [[ -L /var/log/corebrum/install-latest.log || -f /var/log/corebrum/install-latest.log ]]; then
    printf 'log: /var/log/corebrum/install-latest.log\n'
  else
    printf 'log: none\n'
  fi
}

corebrum_cmd_config() {
  local path
  corebrum_cmd_version
  printf 'checkout: %s\n' "$COREBRUM_ROOT"
  printf 'system config: /etc/corebrum\n'
  printf 'logs: /var/log/corebrum\n'
  printf 'backups: /var/log/corebrum/backups\n'
  printf 'command: %s\n' "$COREBRUM_COMMAND_PATH"
  printf 'grid: /etc/corebrum/dashboard/tiles.conf\n'
  printf 'launcher: /etc/corebrum/fuzzel/fuzzel.ini\n'
  printf 'menu: %s\n' "$COREBRUM_LAUNCHER_PATH"
  printf 'ros: /etc/corebrum/ros\n'
  printf 'zenoh router: corebrum-zenoh-router.service\n'
  printf 'user home: not written\n'
  printf 'netplan: existing files are not edited\n'
  if [[ -d /etc/corebrum ]]; then
    printf 'files:\n'
    while IFS= read -r path; do
      printf '  %s\n' "$path"
    done < <(find /etc/corebrum -type f | sort)
  fi
}

corebrum_state_duplicates() {
  local state="/etc/corebrum/desktop.state"
  [[ -f "$state" ]] || return 0
  awk -F= 'NF && $1 !~ /^#/ { print $1 }' "$state" | sort | uniq -d
}

corebrum_run_check() {
  local name="$1"
  local script="$2"
  local next="$3"
  corebrum_log "doctor: ${name}"
  if bash "$script"; then
    return 0
  fi
  corebrum_log "doctor: ${name} failed"
  corebrum_log "next: ${next}"
  return 1
}

corebrum_cmd_doctor() {
  local failed=0 duplicates
  if ! corebrum_run_check base "${COREBRUM_ROOT}/scripts/validate/base.sh" \
    "sudo corebrum install base"; then
    failed=1
  fi
  if [[ -f /etc/corebrum/hypr/hyprland.conf ]]; then
    if ! corebrum_run_check desktop "${COREBRUM_ROOT}/scripts/validate/desktop.sh" \
      "sudo corebrum install desktop"; then
      failed=1
    fi
  else
    corebrum_log "doctor: desktop is not installed"
    corebrum_log "next: sudo corebrum install desktop"
    failed=1
  fi
  if [[ -f /etc/xdg/xdg-desktop-portal/hyprland-portals.conf ]]; then
    if ! corebrum_run_check services "${COREBRUM_ROOT}/scripts/validate/services.sh" \
      "sudo corebrum install desktop"; then
      failed=1
    fi
  elif [[ -f /etc/corebrum/hypr/hyprland.conf ]]; then
    corebrum_log "doctor: workstation services are not installed"
    corebrum_log "next: sudo corebrum install desktop"
    failed=1
  fi
  if [[ -f /etc/corebrum/ros/rmw ]] || corebrum_pkg_installed ros-jazzy-ros-base || corebrum_pkg_installed ros-lyrical-ros-base; then
    if ! corebrum_run_check ros "${COREBRUM_ROOT}/scripts/validate/ros.sh" \
      "sudo corebrum install ros"; then
      failed=1
    fi
  else
    corebrum_log "doctor: ros is not installed"
    corebrum_log "optional: sudo corebrum install ros"
  fi
  duplicates="$(corebrum_state_duplicates || true)"
  if [[ -n "$duplicates" ]]; then
    corebrum_log "doctor: duplicate state keys: ${duplicates}"
    failed=1
  elif [[ -f /etc/corebrum/desktop.state ]]; then
    corebrum_log "ok: state file has no duplicate keys"
  fi
  if [[ -e "${HOME}/.config/hypr/hyprland.conf" ]]; then
    corebrum_log "note: ${HOME}/.config/hypr/hyprland.conf is not managed by Corebrum"
  fi
  corebrum_log "ok: installer does not write ~/.config"
  if [[ -L /var/log/corebrum/install-latest.log || -f /var/log/corebrum/install-latest.log ]]; then
    corebrum_log "log: /var/log/corebrum/install-latest.log"
  fi
  if [[ "$failed" -eq 0 ]]; then
    corebrum_log "doctor: passed"
    return 0
  fi
  corebrum_log "doctor: failed"
  return 1
}

corebrum_cmd_install() {
  local profile="" dry=0 ssh=0
  local -a args=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
      base | desktop | ros)
        profile="$1"
        ;;
      headless)
        profile="base"
        corebrum_log "headless profile is the base profile"
        ;;
      --dry-run)
        dry=1
        ;;
      --enable-ssh)
        ssh=1
        ;;
      -h | --help)
        cat <<'EOF'
Usage: corebrum install base|headless|desktop|ros [--dry-run] [--enable-ssh]

  base, headless   Ubuntu Server foundation. headless is the base profile
  desktop          Base, Hyprland session, and workstation services
  ros              Base, ROS 2, and the Zenoh router. Jazzy on noble, Lyrical on resolute. Not the desktop
  --dry-run        Print the plan without changing the system
  --enable-ssh     Optional OpenSSH server

A real install must be run as root. It does not write ~/.config and it does
not edit existing Netplan files.
EOF
        return 0
        ;;
      *)
        corebrum_die "unknown install argument: $1"
        ;;
    esac
    shift
  done
  [[ -n "$profile" ]] || corebrum_die "missing profile (expected: base, headless, desktop, or ros)"
  args=(--profile "$profile")
  if [[ "$dry" -eq 1 ]]; then
    args+=(--dry-run)
  fi
  if [[ "$ssh" -eq 1 ]]; then
    args+=(--enable-ssh)
  fi
  if "${COREBRUM_ROOT}/scripts/install.sh" "${args[@]}"; then
    return 0
  fi
  corebrum_log "install failed"
  if [[ -L /var/log/corebrum/install-latest.log || -f /var/log/corebrum/install-latest.log ]]; then
    corebrum_log "details: /var/log/corebrum/install-latest.log"
  fi
  corebrum_log "next: corebrum doctor"
  return 1
}

corebrum_cmd_uninstall() {
  local profile="" dry=0
  local -a args=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
      desktop)
        profile="desktop"
        ;;
      ros)
        profile="ros"
        ;;
      base | headless)
        profile="base"
        ;;
      --dry-run)
        dry=1
        ;;
      -h | --help)
        cat <<'EOF'
Usage: corebrum uninstall desktop|ros [--dry-run]

desktop removes Corebrum desktop files and disables greetd. ros disables the
Zenoh router and removes Corebrum ROS files. Neither command removes apt
packages. corebrum uninstall base refuses, because the base profile is
ordinary Ubuntu packages.
EOF
        return 0
        ;;
      *)
        corebrum_die "unknown uninstall argument: $1"
        ;;
    esac
    shift
  done
  [[ -n "$profile" ]] || corebrum_die "missing profile (expected: desktop or ros)"
  args=(--profile "$profile")
  if [[ "$dry" -eq 1 ]]; then
    args+=(--dry-run)
  fi
  "${COREBRUM_ROOT}/scripts/uninstall.sh" "${args[@]}"
}
