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
require "bind = \$mainMod SHIFT, Return, exec, firefox"
require "bind = \$mainMod, W, killactive"
if grep -q 'bind = $mainMod, Q, killactive' "$conf"; then
  echo "FAIL: Super+Q still closes the focused window" >&2
  exit 1
fi
require "fullscreen"
require "togglespecialworkspace, agent"
require "/usr/local/bin/corebrum-lock"
require "workspace, 1"
require "/usr/local/bin/corebrum-grid"
require "/usr/local/bin/corebrum-launcher"
if ! grep -q '/usr/local/bin/corebrum-agents-menu refresh' "${ROOT}/scripts/desktop/corebrum-launcher.sh"; then
  echo "FAIL: Super+Space does not refresh the AI Agents entry" >&2
  exit 1
fi
if ! grep -q '/usr/local/bin/corebrum-chromium-menu refresh' "${ROOT}/scripts/desktop/corebrum-launcher.sh"; then
  echo "FAIL: Super+Space does not refresh the Chromium entry" >&2
  exit 1
fi
if ! grep -q '/usr/local/bin/corebrum-wallpaper-menu refresh' "${ROOT}/scripts/desktop/corebrum-launcher.sh"; then
  echo "FAIL: Super+Space does not refresh the Wallpaper entry" >&2
  exit 1
fi
if grep -q 'corebrum-waypaper-menu refresh' "${ROOT}/scripts/desktop/corebrum-launcher.sh"; then
  echo "FAIL: Super+Space still refreshes Waypaper" >&2
  exit 1
fi
if ! grep -q '/usr/local/bin/corebrum-keys-menu refresh' "${ROOT}/scripts/desktop/corebrum-launcher.sh"; then
  echo "FAIL: Super+Space does not refresh the Keybindings entry" >&2
  exit 1
fi
if ! grep -q '/usr/local/bin/corebrum-realsense-menu refresh' "${ROOT}/scripts/desktop/corebrum-launcher.sh"; then
  echo "FAIL: Super+Space does not refresh the RealSense entry" >&2
  exit 1
fi
if ! grep -q -- "fuzzel --config /etc/corebrum/fuzzel/fuzzel.ini --prompt ''" "${ROOT}/scripts/desktop/corebrum-launcher.sh"; then
  echo "FAIL: Super+Space launcher does not start Fuzzel with a blank search field" >&2
  exit 1
fi
require "waybar --config /etc/corebrum/waybar/config.json"
require "disable_splash_rendering = true"
require 'cmd=$(command -v hyprpaper)'
require 'corebrum/hyprpaper.conf'
if grep -q 'waypaper --restore' "$conf"; then
  echo "FAIL: the session still restores Waypaper" >&2
  exit 1
fi
if ! grep -q 'Corebrum: The Physical AI Operating System' "${ROOT}/config/waybar/config.json"; then
  echo "FAIL: the desktop tagline is missing from Waybar" >&2
  exit 1
fi
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
  echo "FAIL: the text greeter does not start the Corebrum session" >&2
  exit 1
fi
if ! grep -q "corebrum-greeter" "${ROOT}/config/greetd/gtkgreet.toml"; then
  echo "FAIL: gtkgreet does not start the Corebrum greeter" >&2
  exit 1
fi
if ! grep -q -- "--command /usr/local/bin/corebrum-session" "${ROOT}/scripts/desktop/corebrum-greeter.sh"; then
  echo "FAIL: gtkgreet does not start the Corebrum session" >&2
  exit 1
fi
if ! grep -q 'hyprlock --config /etc/corebrum/hypr/hyprlock.conf' "${ROOT}/scripts/desktop/corebrum-lock.sh"; then
  echo "FAIL: the lock command does not use the system hyprlock config" >&2
  exit 1
fi
if ! grep -q '/usr/share/hypr/wall2.png' "${ROOT}/config/hypr/hyprlock.conf"; then
  echo "FAIL: the lock screen does not use the Hyprland wallpaper" >&2
  exit 1
fi
if ! grep -q '/usr/share/hypr/wall2.png' "${ROOT}/config/greetd/gtkgreet.css"; then
  echo "FAIL: the login screen does not use the Hyprland wallpaper" >&2
  exit 1
fi
if ! grep -q 'hyprlock gtkgreet cage' "${ROOT}/scripts/phases/02-desktop.sh"; then
  echo "FAIL: the desktop profile does not consider hyprlock, gtkgreet, and cage" >&2
  exit 1
fi
for greet in "${ROOT}/config/greetd/config.toml" "${ROOT}/config/greetd/gtkgreet.toml"; do
  if ! grep -q '^vt = 7$' "$greet"; then
    echo "FAIL: ${greet} should stay on VT 7 so VT 1 remains a text console" >&2
    exit 1
  fi
done

echo "ok: desktop-config"
