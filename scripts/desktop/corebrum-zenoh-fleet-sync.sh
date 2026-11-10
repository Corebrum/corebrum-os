#!/usr/bin/env bash
# Enable fleet auto-sync and run corebrum zenoh fleet sync when needed.
set -euo pipefail

corebrum_zenoh_fleet_sync_dir() {
  printf '%s\n' "${HOME:-.}/local-fleet"
}

corebrum_zenoh_fleet_sync_once() {
  local dir
  dir="$(corebrum_zenoh_fleet_sync_dir)"
  [[ -f "${dir}/fleet.json" ]] || return 0
  if sudo -n corebrum zenoh fleet sync "$dir" 2>/dev/null; then
    return 0
  fi
  sudo corebrum zenoh fleet sync "$dir"
}

corebrum_zenoh_fleet_sync_start() {
  if command -v systemctl >/dev/null 2>&1 && [[ -n "${XDG_RUNTIME_DIR:-}" ]]; then
    systemctl --user daemon-reload 2>/dev/null || true
    systemctl --user enable --now corebrum-zenoh-fleet.path 2>/dev/null || true
  fi
  corebrum_zenoh_fleet_sync_once &
}

case "${1:-start}" in
  start) corebrum_zenoh_fleet_sync_start ;;
  sync) corebrum_zenoh_fleet_sync_once ;;
  *)
    printf 'Usage: corebrum-zenoh-fleet-sync start|sync\n' >&2
    exit 1
    ;;
esac
