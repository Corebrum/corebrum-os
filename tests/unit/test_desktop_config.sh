#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
conf="${ROOT}/config/hypr/hyprland.conf"

require() {
  local needle="$1"
  if ! grep -qF -- "$needle" "$conf"; then
    echo "FAIL: hyprland.conf missing ${needle}" >&2
    exit 1
  fi
}

require "layout = dwindle"
require "preserve_split = true"
if grep -Eq '^[[:space:]]*pseudotile[[:space:]]*=' "$conf"; then
  echo "FAIL: dwindle:pseudotile was removed in Hyprland 0.55" >&2
  exit 1
fi
require "/usr/local/bin/corebrum-terminal"
require "fullscreen"
require "togglespecialworkspace, agent"
require "workspace, 1"
require "/usr/local/bin/corebrum-grid"
require "fuzzel --config /etc/corebrum/fuzzel/fuzzel.ini"
require "waybar --config /etc/corebrum/waybar/config.json"
require "/usr/libexec/polkit-mate-authentication-agent-1"
require "nm-applet --indicator"
require "blueman-applet"
require "systemctl --user start thunar.service"
# shellcheck disable=SC2016
require 'ln -sfn "$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE" "/tmp/hypr/$HYPRLAND_INSTANCE_SIGNATURE"'
require "wl-paste --watch cliphist store"
if grep -q 'grimshot' "$conf"; then
  echo "FAIL: grimshot depends on sway and is not part of the session" >&2
  exit 1
fi

python3 -c 'import json,sys; json.load(open(sys.argv[1], encoding="utf-8"))' \
  "${ROOT}/config/waybar/config.json"

if ! grep -q '/etc/profile.d/corebrum-ros.sh' "${ROOT}/scripts/desktop/corebrum-session.sh"; then
  echo "FAIL: the session does not source the ROS profile when it is installed" >&2
  exit 1
fi
if ! grep -q '/etc/profile.d/corebrum-ros.sh' "${ROOT}/scripts/desktop/corebrum-terminal.sh"; then
  echo "FAIL: a new terminal does not source the ROS profile" >&2
  exit 1
fi
if ! grep -q "agreety --cmd /usr/local/bin/corebrum-session" "${ROOT}/config/greetd/config.toml"; then
  echo "FAIL: greetd does not start the Corebrum session" >&2
  exit 1
fi
if ! grep -q '^vt = 7$' "${ROOT}/config/greetd/config.toml"; then
  echo "FAIL: greetd should stay on VT 7 so VT 1 remains a text console" >&2
  exit 1
fi

echo "ok: desktop-config"
