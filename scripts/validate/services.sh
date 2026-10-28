#!/usr/bin/env bash
# Validate a completed Phase 3 install. Safe to run as a normal user.
# Package and service checks do not prove playback, Wi-Fi association, or a browser share.
set -euo pipefail

COREBRUM_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=../lib/log.sh
source "${COREBRUM_ROOT}/scripts/lib/log.sh"
# shellcheck source=../lib/manifest.sh
source "${COREBRUM_ROOT}/scripts/lib/manifest.sh"

DRY_RUN=0
failed=0
packages=()
runtime=""
portal="/etc/xdg/xdg-desktop-portal/hyprland-portals.conf"
nm_conf="/usr/lib/NetworkManager/conf.d/10-globally-managed-devices.conf"
wifi_lines=""

corebrum_load_manifest "${COREBRUM_ROOT}/manifests/packages/services.txt" packages

for pkg in "${packages[@]}"; do
  status="$(dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null || true)"
  if [[ "$status" == "install ok installed" ]]; then
    corebrum_log "ok: ${pkg}"
  else
    corebrum_log "missing: ${pkg}"
    failed=1
  fi
done

if compgen -G '/etc/netplan/*.yaml' >/dev/null; then
  corebrum_log "ok: netplan files present"
else
  corebrum_log "missing: /etc/netplan yaml"
  failed=1
fi

if [[ -f "$nm_conf" ]] && grep -qxF 'unmanaged-devices=*,except:type:wifi,except:type:gsm,except:type:cdma' "$nm_conf"; then
  corebrum_log "ok: NetworkManager leaves non-wifi devices unmanaged"
else
  corebrum_log "missing: NetworkManager wifi-only unmanaged policy"
  failed=1
fi

if [[ -f "$portal" ]] && grep -q 'org.freedesktop.impl.portal.ScreenCast=wlr' "$portal"; then
  corebrum_log "ok: wlr screen-cast portal"
else
  corebrum_log "missing: wlr screen-cast portal config"
  failed=1
fi

if [[ -f /etc/corebrum/sway/config ]]; then
  sway_portal="/etc/xdg/xdg-desktop-portal/sway-portals.conf"
  if [[ -f "$sway_portal" ]] && grep -q 'org.freedesktop.impl.portal.ScreenCast=wlr' "$sway_portal"; then
    corebrum_log "ok: sway screen-cast portal"
  else
    corebrum_log "missing: sway screen-cast portal config"
    failed=1
  fi
fi

if ip -4 route show default 2>/dev/null | grep -q .; then
  corebrum_log "ok: default route"
else
  corebrum_log "missing: default IPv4 route"
  failed=1
fi

if systemctl is-active --quiet NetworkManager.service; then
  corebrum_log "ok: NetworkManager.service"
else
  corebrum_log "missing: NetworkManager.service active"
  failed=1
fi

wait_online="$(systemctl is-enabled NetworkManager-wait-online.service 2>/dev/null || true)"
if [[ "$wait_online" == "disabled" || "$wait_online" == "masked" ]]; then
  corebrum_log "ok: NetworkManager-wait-online disabled"
else
  corebrum_log "missing: NetworkManager-wait-online disabled"
  failed=1
fi

for unit in bluetooth.service power-profiles-daemon.service; do
  if systemctl is-active --quiet "$unit"; then
    corebrum_log "ok: ${unit}"
  else
    corebrum_log "missing: ${unit} active"
    failed=1
  fi
done

if command -v nmcli >/dev/null 2>&1; then
  wifi_lines="$(nmcli -t -f TYPE,STATE device 2>/dev/null | grep '^wifi:' || true)"
  if [[ -z "$wifi_lines" ]]; then
    corebrum_log "ok: no wifi device to manage"
  elif grep -q 'unmanaged' <<<"$wifi_lines"; then
    corebrum_log "missing: wifi device is unmanaged"
    failed=1
  else
    corebrum_log "ok: wifi device is managed"
  fi
else
  corebrum_log "missing: nmcli"
  failed=1
fi

for cmd in wpctl nm-connection-editor blueman-manager wdisplays wlr-randr grim slurp wl-copy brightnessctl; do
  if command -v "$cmd" >/dev/null 2>&1; then
    corebrum_log "ok: command ${cmd}"
  else
    corebrum_log "missing: command ${cmd}"
    failed=1
  fi
done

runtime="/run/user/$(id -u)"
if [[ -S "${runtime}/bus" ]]; then
  if XDG_RUNTIME_DIR="$runtime" systemctl --user is-active --quiet wireplumber.service; then
    corebrum_log "ok: wireplumber.service"
  else
    corebrum_log "missing: wireplumber.service active"
    failed=1
  fi
  if XDG_RUNTIME_DIR="$runtime" wpctl status >/dev/null 2>&1; then
    corebrum_log "ok: wpctl"
  else
    corebrum_log "missing: wpctl status"
    failed=1
  fi
else
  corebrum_log "no user bus; skipped wireplumber and wpctl"
fi

if [[ "$failed" -eq 0 ]]; then
  corebrum_log "workstation service validation passed; confirm Wi-Fi join, playback, a USB drive in Thunar, wdisplays, and a browser screen share"
else
  corebrum_log "workstation service validation failed"
fi

exit "$failed"
