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
  /etc/corebrum/hypr/hyprlock.conf \
  /etc/corebrum/greetd/gtkgreet.css \
  /usr/local/bin/corebrum-greeter \
  /usr/local/bin/corebrum-lock \
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
  /usr/local/bin/corebrum-grid \
  /usr/local/bin/corebrum-launcher \
  /usr/local/bin/corebrum-ros-menu \
  /usr/local/bin/corebrum-realsense-menu \
  /usr/local/bin/corebrum-chromium-menu \
  /usr/local/bin/corebrum-agents-menu \
  /usr/local/bin/corebrum-wallpaper-menu \
  /etc/systemd/user/hyprpaper.service.d/corebrum.conf \
  /usr/local/bin/corebrum-keys-menu \
  /etc/corebrum/agents.conf \
  /etc/corebrum/ros-tools.conf
do
  if [[ -f "$path" ]]; then
    corebrum_log "ok: ${path}"
  else
    corebrum_log "missing: ${path}"
    failed=1
  fi
done

bg_policy="$(apt-cache policy hyprland-backgrounds 2>/dev/null || true)"
bg_candidate="$(awk '/^  Candidate:/ { print $2; exit }' <<<"$bg_policy")"
if [[ -n "$bg_candidate" && "$bg_candidate" != "(none)" ]]; then
  status="$(dpkg-query -W -f='${Status}' hyprland-backgrounds 2>/dev/null || true)"
  if [[ "$status" == "install ok installed" ]]; then
    corebrum_log "ok: hyprland-backgrounds"
  else
    corebrum_log "missing: hyprland-backgrounds"
    failed=1
  fi
fi

for cmd in waybar kitty fuzzel wofi agreety; do
  if command -v "$cmd" >/dev/null 2>&1; then
    corebrum_log "ok: command ${cmd}"
  else
    corebrum_log "missing: command ${cmd}"
    failed=1
  fi
done

for pkg in hyprlock gtkgreet cage; do
  policy="$(apt-cache policy "$pkg" 2>/dev/null || true)"
  candidate="$(awk '/^  Candidate:/ { print $2; exit }' <<<"$policy")"
  if [[ -n "$candidate" && "$candidate" != "(none)" ]]; then
    status="$(dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null || true)"
    if [[ "$status" == "install ok installed" ]]; then
      corebrum_log "ok: ${pkg}"
    else
      corebrum_log "missing: ${pkg}"
      failed=1
    fi
  fi
done

if command -v gtkgreet >/dev/null 2>&1 && command -v cage >/dev/null 2>&1; then
  if grep -q 'corebrum-greeter' /etc/greetd/config.toml; then
    corebrum_log "ok: gtkgreet login"
  else
    corebrum_log "missing: gtkgreet login"
    failed=1
  fi
elif grep -q 'agreety --cmd /usr/local/bin/corebrum-session' /etc/greetd/config.toml; then
  corebrum_log "ok: agreety login"
else
  corebrum_log "missing: login command"
  failed=1
fi

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

node_version="$(bash --noprofile --norc -c 'set +u; . /etc/profile.d/corebrum-node.sh; node -v' 2>/dev/null || true)"
npm_version="$(bash --noprofile --norc -c 'set +u; . /etc/profile.d/corebrum-node.sh; npm -v' 2>/dev/null || true)"
pnpm_version="$(bash --noprofile --norc -c 'set +u; . /etc/profile.d/corebrum-node.sh; pnpm -v' 2>/dev/null || true)"
if [[ "$node_version" == v26.* ]]; then
  corebrum_log "ok: node ${node_version}"
else
  corebrum_log "missing: node 26.x (${node_version:-not installed})"
  failed=1
fi
if [[ -n "$npm_version" ]]; then
  corebrum_log "ok: npm ${npm_version}"
else
  corebrum_log "missing: npm"
  failed=1
fi
if [[ -n "$pnpm_version" ]]; then
  corebrum_log "ok: pnpm ${pnpm_version}"
else
  corebrum_log "missing: pnpm"
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
