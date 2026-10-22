#!/usr/bin/env bash
# Validate a completed desktop-profile install. Safe to run as a normal user.
# Package and file checks do not prove that Hyprland started. See docs/installation/desktop.md.
set -euo pipefail

COREBRUM_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=../lib/log.sh
source "${COREBRUM_ROOT}/scripts/lib/log.sh"
# shellcheck source=../lib/manifest.sh
source "${COREBRUM_ROOT}/scripts/lib/manifest.sh"

DRY_RUN=0
failed=0
packages=()
path=""

corebrum_load_manifest "${COREBRUM_ROOT}/manifests/packages/desktop.txt" packages

for pkg in "${packages[@]}"; do
  status="$(dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null || true)"
  if [[ "$status" == "install ok installed" ]]; then
    corebrum_log "ok: ${pkg}"
  else
    corebrum_log "missing: ${pkg}"
    failed=1
  fi
done

for path in \
  /etc/corebrum/hypr/hyprland.conf \
  /etc/corebrum/waybar/config.json \
  /etc/corebrum/waybar/style.css \
  /etc/corebrum/kitty/kitty.conf \
  /etc/corebrum/fuzzel/fuzzel.ini \
  /etc/corebrum/mako/config \
  /etc/corebrum/wofi/config \
  /etc/corebrum/dashboard/tiles.conf \
  /etc/greetd/config.toml \
  /usr/local/bin/corebrum-session \
  /usr/local/bin/corebrum-terminal \
  /usr/local/bin/corebrum-grid
do
  if [[ -f "$path" ]]; then
    corebrum_log "ok: ${path}"
  else
    corebrum_log "missing: ${path}"
    failed=1
  fi
done

for cmd in waybar kitty fuzzel wofi agreety; do
  if command -v "$cmd" >/dev/null 2>&1; then
    corebrum_log "ok: command ${cmd}"
  else
    corebrum_log "missing: command ${cmd}"
    failed=1
  fi
done

if command -v Hyprland >/dev/null 2>&1 || command -v hyprland >/dev/null 2>&1; then
  corebrum_log "ok: command Hyprland"
  hyprland_bin="$(command -v Hyprland || command -v hyprland)"
  verify_log="$(mktemp)"
  # Hyprland writes a debug log beside the working directory when stdout logs are off.
  if (cd /tmp && "$hyprland_bin" --verify-config --config /etc/corebrum/hypr/hyprland.conf >"$verify_log" 2>&1); then
    corebrum_log "ok: Hyprland config"
  else
    corebrum_log "Hyprland config errors:"
    grep -E 'Config error|error' "$verify_log" >&2 || true
    failed=1
  fi
  rm -f "$verify_log"
else
  corebrum_log "missing: command Hyprland"
  failed=1
fi

if systemctl is-enabled greetd.service 2>/dev/null | grep -qx enabled; then
  corebrum_log "ok: greetd.service enabled"
else
  corebrum_log "missing: greetd.service enabled"
  failed=1
fi

if [[ "$(systemctl get-default 2>/dev/null || true)" == "graphical.target" ]]; then
  corebrum_log "ok: default target graphical.target"
else
  corebrum_log "missing: default target graphical.target"
  failed=1
fi

if [[ -x /usr/local/bin/corebrum-grid ]] && /usr/local/bin/corebrum-grid --list | grep -qx Terminal; then
  corebrum_log "ok: app grid lists Terminal"
else
  corebrum_log "missing: app grid Terminal tile"
  failed=1
fi

if [[ "$failed" -eq 0 ]]; then
  corebrum_log "desktop file validation passed; log in on VT 7 and confirm Hyprland, Super+Return, tiling, workspaces, fullscreen, and Waybar"
else
  corebrum_log "desktop validation failed"
fi

exit "$failed"
