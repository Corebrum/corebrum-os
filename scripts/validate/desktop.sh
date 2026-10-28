#!/usr/bin/env bash
# Validate a completed desktop-profile install. Safe to run as a normal user.
# Package and file checks do not prove that Sway started. See docs/installation/desktop.md.
set -euo pipefail

COREBRUM_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=../lib/log.sh
source "${COREBRUM_ROOT}/scripts/lib/log.sh"
# shellcheck source=../lib/manifest.sh
source "${COREBRUM_ROOT}/scripts/lib/manifest.sh"
# shellcheck source=../lib/archive.sh
source "${COREBRUM_ROOT}/scripts/lib/archive.sh"
# shellcheck source=../lib/ppa.sh
source "${COREBRUM_ROOT}/scripts/lib/ppa.sh"
# shellcheck source=../lib/preflight.sh
source "${COREBRUM_ROOT}/scripts/lib/preflight.sh"

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
  /etc/corebrum/sway/config \
  /etc/corebrum/gtklock/config.ini \
  /etc/corebrum/gtklock/style.css \
  /etc/corebrum/gtklock/layout.ui \
  /etc/corebrum/sway/idle.conf \
  /etc/corebrum/greetd/wlgreet.toml \
  /etc/corebrum/greetd/login.css \
  /etc/corebrum/greetd/sway-config \
  /usr/share/corebrum/logo.png \
  /usr/share/corebrum/agenticros.png \
  /usr/share/corebrum/ollama.png \
  /usr/share/corebrum/ros.png \
  /usr/share/corebrum/zenoh.png \
  /usr/share/corebrum/realsense.png \
  /usr/share/corebrum/agents.png \
  /usr/share/corebrum/agents/antigravity.png \
  /usr/share/corebrum/agents/claude.png \
  /usr/share/corebrum/agents/codex.png \
  /usr/share/corebrum/agents/cursor.png \
  /usr/share/corebrum/agents/grok.webp \
  /usr/share/corebrum/agents/hermes.png \
  /usr/share/corebrum/agents/openclaw.png \
  /usr/local/bin/corebrum-greetd \
  /usr/local/bin/corebrum-greeter \
  /usr/local/bin/corebrum-login \
  /usr/local/bin/corebrum-login-logo \
  /usr/local/lib/corebrum/vc4.sh \
  /usr/local/lib/corebrum/drm.sh \
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
  /usr/local/bin/corebrum-setup \
  /usr/local/bin/corebrum-terminal \
  /usr/local/bin/corebrum-grid \
  /usr/local/bin/corebrum-launcher \
  /usr/local/bin/corebrum-ros-menu \
  /usr/local/bin/corebrum-realsense-menu \
  /usr/local/bin/corebrum-chromium-menu \
  /usr/local/bin/corebrum-arc-menu \
  /usr/local/bin/corebrum-ollama-menu \
  /usr/local/bin/corebrum-zenoh-fleet-menu \
  /usr/local/bin/corebrum-agents-menu \
  /usr/local/bin/corebrum-updates-menu \
  /usr/local/bin/corebrum-wallpaper-menu \
  /etc/systemd/user/hyprpaper.service.d/corebrum.conf \
  /usr/local/bin/corebrum-keys-menu \
  /usr/local/bin/corebrum-docs-menu \
  /usr/local/bin/corebrum-osd \
  /usr/local/bin/corebrum-autolock \
  /usr/local/bin/corebrum-power-menu \
  /usr/local/bin/corebrum-vnc-menu \
  /usr/local/bin/corebrum-vnc-proxy \
  /usr/local/bin/corebrum-record \
  /usr/local/lib/corebrum/corebrum-camera-preview.py \
  /etc/systemd/user/hypridle.service.d/corebrum.conf \
  /etc/corebrum/agents.conf \
  /etc/corebrum/ros-tools.conf \
  /usr/share/corebrum/getting-started/index.html \
  /usr/share/corebrum/getting-started/nav.html \
  /usr/share/corebrum/getting-started/ros.html \
  /usr/share/corebrum/getting-started/zenoh.html \
  /usr/local/lib/corebrum/getting-started-server.js \
  /usr/local/bin/corebrum-getting-started \
  /etc/systemd/system/corebrum-getting-started.service \
  /etc/firefox/policies/policies.json
do
  if [[ -f "$path" ]]; then
    corebrum_log "ok: ${path}"
  else
    corebrum_log "missing: ${path}"
    failed=1
  fi
done

for path in \
  /usr/local/bin/corebrum-record \
  /usr/local/lib/corebrum/corebrum-camera-preview.py \
  /usr/local/bin/corebrum-getting-started
do
  if [[ -x "$path" ]]; then
    corebrum_log "ok: ${path} is executable"
  else
    corebrum_log "not executable: ${path}"
    failed=1
  fi
done

if systemctl is-enabled --quiet corebrum-getting-started.service; then
  corebrum_log "ok: corebrum-getting-started.service enabled"
else
  corebrum_log "missing: corebrum-getting-started.service enabled"
  failed=1
fi

for cmd in waybar kitty fuzzel wofi agreety; do
  if command -v "$cmd" >/dev/null 2>&1; then
    corebrum_log "ok: command ${cmd}"
  else
    corebrum_log "missing: command ${cmd}"
    failed=1
  fi
done

codename="$(corebrum_read_os_release_field /etc/os-release VERSION_CODENAME || true)"
locker="$(corebrum_lock_package "$codename" || true)"
[[ -n "$locker" ]] || locker=gtklock
if [[ "$locker" == "swaylock" ]]; then
  if [[ -f /etc/corebrum/sway/swaylock.conf ]]; then
    corebrum_log "ok: /etc/corebrum/sway/swaylock.conf"
  else
    corebrum_log "missing: /etc/corebrum/sway/swaylock.conf"
    failed=1
  fi
fi
for pkg in swaybg swayidle wlgreet "$locker"; do
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

if command -v wlgreet >/dev/null 2>&1 && command -v sway >/dev/null 2>&1; then
  if grep -q 'corebrum-greetd' /etc/greetd/config.toml \
    && grep -q 'sway --config /etc/corebrum/greetd/sway-config' /usr/local/bin/corebrum-greetd; then
    corebrum_log "ok: wlgreet login"
  else
    corebrum_log "missing: wlgreet login"
    failed=1
  fi
elif grep -q 'agreety --cmd /usr/local/bin/corebrum-session' /etc/greetd/config.toml; then
  corebrum_log "ok: agreety login"
else
  corebrum_log "missing: login command"
  failed=1
fi

if command -v sway >/dev/null 2>&1; then
  corebrum_log "ok: command sway"
  verify_log="$(mktemp)"
  if sway -c /etc/corebrum/sway/config -C >"$verify_log" 2>&1; then
    corebrum_log "ok: Sway config"
  else
    corebrum_log "Sway config errors:"
    cat "$verify_log" >&2 || true
    failed=1
  fi
  if sway -c /etc/corebrum/greetd/sway-config -C >"$verify_log" 2>&1; then
    corebrum_log "ok: greeter Sway config"
  else
    corebrum_log "greeter Sway config errors:"
    cat "$verify_log" >&2 || true
    failed=1
  fi
  rm -f "$verify_log"
else
  corebrum_log "missing: command sway"
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
  corebrum_log "desktop file validation passed; log in on VT 7 and confirm Sway, Super+Return, tiling, workspaces, fullscreen, and Waybar"
else
  corebrum_log "desktop validation failed"
fi

exit "$failed"
