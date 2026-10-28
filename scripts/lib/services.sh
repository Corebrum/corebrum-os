#!/usr/bin/env bash
# Phase 3 workstation helpers. Source this file; do not execute it.
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  echo "source scripts/lib/services.sh from another script" >&2
  exit 1
fi

# shellcheck source=files.sh
source "${COREBRUM_ROOT}/scripts/lib/files.sh"
# shellcheck source=manifest.sh
source "${COREBRUM_ROOT}/scripts/lib/manifest.sh"
# shellcheck source=ppa.sh
source "${COREBRUM_ROOT}/scripts/lib/ppa.sh"

COREBRUM_NM_UNMANAGED_LINE='unmanaged-devices=*,except:type:wifi,except:type:gsm,except:type:cdma'
WAYLAND_DISPLAY=""
XDG_RUNTIME_DIR=""
DBUS_SESSION_BUS_ADDRESS=""
HYPRLAND_INSTANCE_SIGNATURE=""
XDG_CURRENT_DESKTOP=""
XDG_SESSION_TYPE=""
DISPLAY=""

corebrum_services_require_archive() {
  local manifest="${COREBRUM_ROOT}/manifests/packages/services.txt"
  local -a packages=()
  local pkg version
  corebrum_load_manifest "$manifest" packages
  for pkg in "${packages[@]}"; do
    version="$(corebrum_ubuntu_archive_version "$pkg")"
    if [[ -z "$version" ]]; then
      corebrum_die "${pkg} is not in the Ubuntu archive; Phase 3 does not take it from a PPA"
    fi
  done
  corebrum_log "workstation packages are in the Ubuntu archive"
}

# Ubuntu's NetworkManager package leaves ethernet unmanaged. Refuse any other policy.
corebrum_require_nm_wifi_only() {
  local conf="/usr/lib/NetworkManager/conf.d/10-globally-managed-devices.conf"
  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    corebrum_log "dry-run: require NetworkManager to leave non-wifi devices unmanaged"
    return 0
  fi
  if [[ ! -f "$conf" ]] || ! grep -qxF "$COREBRUM_NM_UNMANAGED_LINE" "$conf"; then
    systemctl disable NetworkManager-wait-online.service >/dev/null 2>&1 || true
    systemctl stop NetworkManager.service >/dev/null 2>&1 || true
    systemctl disable NetworkManager.service >/dev/null 2>&1 || true
    corebrum_die "NetworkManager would manage ethernet; stopped it and left /etc/netplan unchanged"
  fi
  corebrum_log "NetworkManager manages wifi only"
}

corebrum_disable_nm_wait_online() {
  local state
  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    corebrum_log "dry-run: systemctl disable NetworkManager-wait-online.service so boot does not wait for wifi"
    return 0
  fi
  state="$(systemctl is-enabled NetworkManager-wait-online.service 2>/dev/null || true)"
  if [[ "$state" == "disabled" || "$state" == "masked" || -z "$state" ]]; then
    corebrum_log "NetworkManager-wait-online is ${state:-not installed}"
    return 0
  fi
  corebrum_log "run: systemctl disable --now NetworkManager-wait-online.service"
  systemctl disable --now NetworkManager-wait-online.service
}

corebrum_enable_system_unit() {
  local key="$1"
  local unit="$2"
  local state
  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    corebrum_log "dry-run: systemctl enable --now ${unit} when it is not already enabled"
    return 0
  fi
  state="$(systemctl is-enabled "$unit" 2>/dev/null || true)"
  if [[ "$state" == "enabled" ]]; then
    corebrum_log "already enabled: ${unit}"
    systemctl start "$unit"
    return 0
  fi
  corebrum_state_set_once "$key" "1"
  corebrum_log "run: systemctl enable --now ${unit}"
  systemctl enable --now "$unit"
}

corebrum_enable_user_unit() {
  local key="$1"
  local unit="$2"
  local state
  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    corebrum_log "dry-run: systemctl --global enable ${unit} when it is not already enabled"
    return 0
  fi
  state="$(systemctl --global is-enabled "$unit" 2>/dev/null || true)"
  if [[ "$state" == "enabled" ]]; then
    corebrum_log "already enabled for users: ${unit}"
    return 0
  fi
  corebrum_state_set_once "$key" "1"
  corebrum_log "run: systemctl --global enable ${unit}"
  systemctl --global enable "$unit"
}

corebrum_disable_recorded_system_unit() {
  local key="$1"
  local unit="$2"
  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    corebrum_log "dry-run: systemctl disable ${unit} when Corebrum enabled it"
    return 0
  fi
  if ! corebrum_state_get "$key" >/dev/null; then
    return 0
  fi
  corebrum_log "run: systemctl disable --now ${unit}"
  systemctl disable --now "$unit" || corebrum_log "could not disable ${unit}"
}

corebrum_disable_recorded_user_unit() {
  local key="$1"
  local unit="$2"
  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    corebrum_log "dry-run: systemctl --global disable ${unit} when Corebrum enabled it"
    return 0
  fi
  if ! corebrum_state_get "$key" >/dev/null; then
    return 0
  fi
  corebrum_log "run: systemctl --global disable ${unit}"
  systemctl --global disable "$unit" || corebrum_log "could not disable ${unit}"
}

corebrum_session_env_from_pid() {
  local pid="$1"
  local item key
  WAYLAND_DISPLAY=""
  XDG_RUNTIME_DIR=""
  DBUS_SESSION_BUS_ADDRESS=""
  HYPRLAND_INSTANCE_SIGNATURE=""
  XDG_CURRENT_DESKTOP=""
  XDG_SESSION_TYPE=""
  DISPLAY=""
  while IFS= read -r -d '' item || [[ -n "$item" ]]; do
    key="${item%%=*}"
    case "$key" in
      WAYLAND_DISPLAY | XDG_RUNTIME_DIR | DBUS_SESSION_BUS_ADDRESS | HYPRLAND_INSTANCE_SIGNATURE | XDG_CURRENT_DESKTOP | XDG_SESSION_TYPE | DISPLAY)
        printf -v "$key" '%s' "${item#*=}"
        ;;
    esac
  done <"/proc/${pid}/environ"
}

corebrum_session_spawn() {
  local user="$1"
  local unit="$2"
  shift 2
  if runuser -u "$user" -- env \
    WAYLAND_DISPLAY="$WAYLAND_DISPLAY" \
    XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR" \
    DBUS_SESSION_BUS_ADDRESS="$DBUS_SESSION_BUS_ADDRESS" \
    HYPRLAND_INSTANCE_SIGNATURE="$HYPRLAND_INSTANCE_SIGNATURE" \
    XDG_CURRENT_DESKTOP="${XDG_CURRENT_DESKTOP:-Hyprland}" \
    XDG_SESSION_TYPE="${XDG_SESSION_TYPE:-wayland}" \
    DISPLAY="${DISPLAY:-}" \
    systemd-run --user --quiet --collect --unit "$unit" "$@"; then
    corebrum_log "started ${unit} for ${user}"
  else
    corebrum_log "could not start ${unit} for ${user}; log in again to pick up workstation services"
  fi
}

corebrum_session_spawn_once() {
  local user="$1"
  local pattern="$2"
  local unit="$3"
  shift 3
  if pgrep -u "$user" -f "$pattern" >/dev/null 2>&1; then
    corebrum_log "already running for ${user}: ${unit}"
    return 0
  fi
  corebrum_session_spawn "$user" "$unit" "$@"
}

corebrum_refresh_one_session() {
  local uid="$1"
  local user="$2"
  local runtime="$3"
  local pid=""
  pid="$(pgrep -u "$uid" -x waybar | head -n 1 || true)"
  if [[ -z "$pid" ]]; then
    pid="$(pgrep -u "$uid" -x mako | head -n 1 || true)"
  fi
  XDG_RUNTIME_DIR="$runtime"
  DBUS_SESSION_BUS_ADDRESS="unix:path=${runtime}/bus"
  if [[ -n "$pid" ]]; then
    corebrum_session_env_from_pid "$pid"
  fi
  if [[ -z "${XDG_RUNTIME_DIR}" || -z "${DBUS_SESSION_BUS_ADDRESS}" ]]; then
    corebrum_log "no session bus for ${user}; audio and helpers start at the next login"
    return 0
  fi
  if runuser -u "$user" -- env \
    XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR" \
    DBUS_SESSION_BUS_ADDRESS="$DBUS_SESSION_BUS_ADDRESS" \
    systemctl --user daemon-reload \
    && runuser -u "$user" -- env \
      XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR" \
      DBUS_SESSION_BUS_ADDRESS="$DBUS_SESSION_BUS_ADDRESS" \
      systemctl --user start pipewire.socket pipewire-pulse.socket wireplumber.service; then
    corebrum_log "audio services started for ${user}"
  else
    corebrum_log "audio services did not start for ${user}; they start at the next login"
  fi
  if [[ -z "${WAYLAND_DISPLAY}" ]]; then
    corebrum_log "no Wayland display for ${user}; bar and applets start at the next login"
    return 0
  fi
  if [[ -n "${HYPRLAND_INSTANCE_SIGNATURE}" ]]; then
    if runuser -u "$user" -- env \
      XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR" \
      HYPRLAND_INSTANCE_SIGNATURE="$HYPRLAND_INSTANCE_SIGNATURE" \
      hyprctl reload; then
      corebrum_log "reloaded Hyprland for ${user}"
    else
      corebrum_log "could not reload Hyprland for ${user}"
    fi
    if [[ -S "${XDG_RUNTIME_DIR}/hypr/${HYPRLAND_INSTANCE_SIGNATURE}/.socket.sock" ]]; then
      runuser -u "$user" -- mkdir -p /tmp/hypr
      runuser -u "$user" -- ln -sfn \
        "${XDG_RUNTIME_DIR}/hypr/${HYPRLAND_INSTANCE_SIGNATURE}" \
        "/tmp/hypr/${HYPRLAND_INSTANCE_SIGNATURE}"
      corebrum_log "linked Waybar to the Hyprland socket for ${user}"
    fi
  fi
  pkill -u "$user" -x waybar >/dev/null 2>&1 || true
  runuser -u "$user" -- env \
    XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR" \
    DBUS_SESSION_BUS_ADDRESS="$DBUS_SESSION_BUS_ADDRESS" \
    systemctl --user stop corebrum-waybar.service >/dev/null 2>&1 || true
  corebrum_session_spawn "$user" corebrum-waybar \
    waybar --config /etc/corebrum/waybar/config.json --style /etc/corebrum/waybar/style.css
  corebrum_session_spawn_once "$user" '[n]m-applet' corebrum-nm-applet nm-applet --indicator
  corebrum_session_spawn_once "$user" '[b]lueman-applet' corebrum-blueman blueman-applet
  corebrum_session_spawn_once "$user" '[p]olkit-mate-authentication-agent-1' corebrum-polkit \
    /usr/libexec/polkit-mate-authentication-agent-1
  if runuser -u "$user" -- env \
    XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR" \
    DBUS_SESSION_BUS_ADDRESS="$DBUS_SESSION_BUS_ADDRESS" \
    systemctl --user start thunar.service; then
    corebrum_log "started thunar.service for ${user}"
  else
    corebrum_log "could not start thunar.service for ${user}; open Files to manage disks"
  fi
  corebrum_session_spawn_once "$user" '[w]l-paste --watch cliphist' corebrum-cliphist \
    wl-paste --watch cliphist store
}

corebrum_refresh_logged_in_sessions() {
  local uid user runtime
  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    corebrum_log "dry-run: start audio and session helpers for logged-in users, and reload Hyprland when a session is running"
    return 0
  fi
  if ! command -v loginctl >/dev/null 2>&1; then
    corebrum_log "loginctl is not available; workstation helpers start at the next login"
    return 0
  fi
  while read -r uid user _; do
    [[ "$uid" =~ ^[0-9]+$ ]] || continue
    [[ -n "$user" ]] || continue
    runtime="/run/user/${uid}"
    [[ -S "${runtime}/bus" ]] || continue
    corebrum_refresh_one_session "$uid" "$user" "$runtime"
  done < <(loginctl list-users --no-legend 2>/dev/null || true)
}

corebrum_uninstall_services() {
  local portal="/etc/xdg/xdg-desktop-portal/hyprland-portals.conf"
  local sway_portal="/etc/xdg/xdg-desktop-portal/sway-portals.conf"
  corebrum_disable_recorded_system_unit enabled_network_manager NetworkManager.service
  corebrum_disable_recorded_system_unit enabled_bluetooth bluetooth.service
  corebrum_disable_recorded_system_unit enabled_power_profiles power-profiles-daemon.service
  corebrum_disable_recorded_user_unit enabled_user_pipewire_pulse_socket pipewire-pulse.socket
  corebrum_disable_recorded_user_unit enabled_user_wireplumber wireplumber.service
  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    corebrum_log "dry-run: remove ${portal} when Corebrum owns it"
    corebrum_log "dry-run: remove ${sway_portal} when Corebrum owns it"
    return 0
  fi
  if [[ -f "$portal" ]] && grep -q "Managed by Corebrum OS" "$portal"; then
    corebrum_backup_file "$portal"
    rm -f "$portal"
    corebrum_log "removed ${portal}"
  fi
  if [[ -f "$sway_portal" ]] && grep -q "Managed by Corebrum OS" "$sway_portal"; then
    corebrum_backup_file "$sway_portal"
    rm -f "$sway_portal"
    corebrum_log "removed ${sway_portal}"
  fi
  rmdir /etc/xdg/xdg-desktop-portal 2>/dev/null || true
}
