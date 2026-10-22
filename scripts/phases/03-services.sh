#!/usr/bin/env bash
# Phase 3 workstation services. Sourced by scripts/install.sh.
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  echo "Run ./scripts/install.sh --profile desktop" >&2
  exit 1
fi

# shellcheck source=../lib/services.sh
source "${COREBRUM_ROOT}/scripts/lib/services.sh"

corebrum_phase_services() {
  local manifest="${COREBRUM_ROOT}/manifests/packages/services.txt"
  local -a packages=()
  corebrum_services_require_archive
  corebrum_log "not changing existing Netplan files or running netplan apply"
  corebrum_load_manifest "$manifest" packages
  corebrum_apt_install --no-install-recommends "${packages[@]}"
  corebrum_require_nm_wifi_only
  corebrum_disable_nm_wait_online
  corebrum_enable_system_unit enabled_network_manager NetworkManager.service
  corebrum_enable_system_unit enabled_bluetooth bluetooth.service
  corebrum_enable_system_unit enabled_power_profiles power-profiles-daemon.service
  corebrum_enable_user_unit enabled_user_pipewire_pulse_socket pipewire-pulse.socket
  corebrum_enable_user_unit enabled_user_wireplumber wireplumber.service
  corebrum_install_file \
    "${COREBRUM_ROOT}/config/xdg/hyprland-portals.conf" \
    /etc/xdg/xdg-desktop-portal/hyprland-portals.conf \
    644
  corebrum_refresh_logged_in_sessions
  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    corebrum_log "workstation services dry-run complete"
  else
    corebrum_log "workstation services install complete; existing Netplan files were not modified"
  fi
}
