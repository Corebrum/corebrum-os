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
require "bind = \$mainMod SHIFT, F, exec, thunar"
require "bind = \$mainMod SHIFT, N, exec, gnome-text-editor"
require "bind = \$mainMod, Print, exec, /usr/local/bin/corebrum-record start"
require "bind = \$mainMod SHIFT, Print, exec, /usr/local/bin/corebrum-record stop"
require "bind = \$mainMod, P, exec,"
require "bind = \$mainMod SHIFT, P, exec,"
require "bind = \$mainMod ALT, P, exec, /usr/local/bin/corebrum-record start"
require "bind = \$mainMod ALT SHIFT, P, exec, /usr/local/bin/corebrum-record stop"
if grep -q 'wf-recorder' "$conf"; then
  echo "FAIL: recording still calls wf-recorder from hyprland.conf" >&2
  exit 1
fi
if ! grep -q 'match:class = \^(corebrum-camera)\$' "$conf"; then
  echo "FAIL: the camera preview has no window rule" >&2
  exit 1
fi
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
if ! grep -q 'Name=Files' "${ROOT}/scripts/desktop/corebrum-launcher.sh"; then
  echo "FAIL: Super+Space does not rename Thunar to Files" >&2
  exit 1
fi
if ! grep -q 'applications/thunar.desktop' "${ROOT}/scripts/desktop/corebrum-launcher.sh"; then
  echo "FAIL: Super+Space does not override the Thunar desktop entry" >&2
  exit 1
fi
if ! grep -q '/usr/local/bin/corebrum-agents-menu refresh &' "${ROOT}/scripts/desktop/corebrum-launcher.sh"; then
  echo "FAIL: Super+Space refreshes AI Agents in series" >&2
  exit 1
fi
if ! grep -q '/usr/local/bin/corebrum-chromium-menu refresh' "${ROOT}/scripts/desktop/corebrum-launcher.sh"; then
  echo "FAIL: Super+Space does not refresh the Chromium entry" >&2
  exit 1
fi
if ! grep -q '/usr/local/bin/corebrum-ollama-menu refresh' "${ROOT}/scripts/desktop/corebrum-launcher.sh"; then
  echo "FAIL: Super+Space does not refresh the Ollama entry" >&2
  exit 1
fi
if ! grep -q '/usr/local/bin/corebrum-zenoh-fleet-menu refresh' "${ROOT}/scripts/desktop/corebrum-launcher.sh"; then
  echo "FAIL: Super+Space does not refresh the Zenoh fleet entry" >&2
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
if ! grep -q '/usr/local/bin/corebrum-keys-menu refresh &' "${ROOT}/scripts/desktop/corebrum-launcher.sh"; then
  echo "FAIL: Super+Space does not refresh the Keybindings entry" >&2
  exit 1
fi
if ! grep -q '/usr/local/bin/corebrum-updates-menu refresh &' "${ROOT}/scripts/desktop/corebrum-launcher.sh"; then
  echo "FAIL: Super+Space does not refresh the Updates entry" >&2
  exit 1
fi
if [[ "$(grep -c 'refresh &' "${ROOT}/scripts/desktop/corebrum-launcher.sh")" -lt 14 ]]; then
  echo "FAIL: Super+Space still refreshes some menu entries in series" >&2
  exit 1
fi
if ! grep -q '/usr/local/bin/corebrum-realsense-menu refresh' "${ROOT}/scripts/desktop/corebrum-launcher.sh"; then
  echo "FAIL: Super+Space does not refresh the RealSense entry" >&2
  exit 1
fi
if ! grep -q '/usr/local/bin/corebrum-agenticros-menu refresh' "${ROOT}/scripts/desktop/corebrum-launcher.sh"; then
  echo "FAIL: Super+Space does not refresh the AgenticROS entry" >&2
  exit 1
fi
if ! grep -q '/usr/local/bin/corebrum-skills-menu refresh' "${ROOT}/scripts/desktop/corebrum-launcher.sh"; then
  echo "FAIL: Super+Space does not refresh the Skills entry" >&2
  exit 1
fi
if ! grep -q -- "fuzzel --config /etc/corebrum/fuzzel/fuzzel.ini --prompt ''" "${ROOT}/scripts/desktop/corebrum-launcher.sh"; then
  echo "FAIL: Super+Space launcher does not start Fuzzel with a blank search field" >&2
  exit 1
fi
require "waybar --config /etc/corebrum/waybar/config.json"
require "disable_splash_rendering = true"
require "/usr/local/bin/corebrum-osd volume-up"
require "/usr/local/bin/corebrum-osd brightness-down"
require "/usr/local/bin/corebrum-autolock start"
require 'corebrum/setup-done'
require '/usr/local/bin/corebrum-updates-menu remind'
require '/usr/local/bin/corebrum-setup login'
require 'match:class = ^(corebrum-setup)$'
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
if ! grep -q 'exec start-hyprland -- --config' "${ROOT}/scripts/desktop/corebrum-session.sh"; then
  echo "FAIL: the session does not start Hyprland through start-hyprland" >&2
  exit 1
fi
if ! grep -q 'exec Hyprland --config' "${ROOT}/scripts/desktop/corebrum-session.sh"; then
  echo "FAIL: the session has no direct Hyprland fallback" >&2
  exit 1
fi
if ! grep -q 'hyprland-qtutils' "${ROOT}/scripts/phases/02-desktop.sh"; then
  echo "FAIL: the desktop profile does not consider hyprland-qtutils" >&2
  exit 1
fi
if ! grep -q 'corebrum_ubuntu_archive_version hyprland-qtutils' "${ROOT}/scripts/phases/02-desktop.sh"; then
  echo "FAIL: hyprland-qtutils is not limited to the Ubuntu archive" >&2
  exit 1
fi
if ! grep -q '/etc/profile.d/corebrum-ros.sh' "${ROOT}/scripts/desktop/corebrum-terminal.sh"; then
  echo "FAIL: a new terminal does not source the ROS profile" >&2
  exit 1
fi
if ! grep -q '\[\[ "\$#" -gt 0 \]\]' "${ROOT}/scripts/desktop/corebrum-terminal.sh"; then
  echo "FAIL: Super+Return sources node and ROS before Kitty opens" >&2
  exit 1
fi
if ! grep -q "agreety --cmd /usr/local/bin/corebrum-session" "${ROOT}/config/greetd/config.toml"; then
  echo "FAIL: the text greeter does not start the Corebrum session" >&2
  exit 1
fi
if ! grep -q "corebrum-greetd" "${ROOT}/config/greetd/gtkgreet.toml"; then
  echo "FAIL: gtkgreet does not start the Corebrum greeter" >&2
  exit 1
fi
if ! grep -q 'exec cage -s -d -- /usr/local/bin/corebrum-greeter' "${ROOT}/scripts/desktop/corebrum-greetd.sh"; then
  echo "FAIL: the greeter wrapper does not keep cage -s -d" >&2
  exit 1
fi
if ! grep -q 'corebrum_vc4_card' "${ROOT}/scripts/lib/vc4.sh"; then
  echo "FAIL: the vc4 helper is missing" >&2
  exit 1
fi
if ! grep -q 'no_hardware_cursors = true' "${ROOT}/scripts/desktop/corebrum-drm.sh"; then
  echo "FAIL: the Pi session does not disable hardware cursors" >&2
  exit 1
fi
if ! grep -q -- "--command /usr/local/bin/corebrum-session" "${ROOT}/scripts/desktop/corebrum-greeter.sh"; then
  echo "FAIL: gtkgreet does not start the Corebrum session" >&2
  exit 1
fi
if ! grep -q -- "--disable-custom-commands" "${ROOT}/scripts/desktop/corebrum-greeter.sh"; then
  echo "FAIL: the login screen still accepts a custom session command" >&2
  exit 1
fi
if ! grep -q '#command-selector' "${ROOT}/config/greetd/gtkgreet.css"; then
  echo "FAIL: the login screen still shows the session dropdown" >&2
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
if ! grep -q '/usr/share/corebrum/logo.png' "${ROOT}/config/hypr/hyprlock.conf"; then
  echo "FAIL: the lock screen does not show the Corebrum logo" >&2
  exit 1
fi
if ! grep -q 'rounding = 0' "${ROOT}/config/hypr/hyprlock.conf"; then
  echo "FAIL: the lock logo uses hyprlock's circle crop" >&2
  exit 1
fi
if ! grep -q 'border_size = 0' "${ROOT}/config/hypr/hyprlock.conf"; then
  echo "FAIL: the lock logo keeps hyprlock's default border" >&2
  exit 1
fi
if ! grep -q 'box#window' "${ROOT}/config/greetd/gtkgreet.css"; then
  echo "FAIL: the login screen does not place the Corebrum logo above the clock" >&2
  exit 1
fi
if ! grep -q '/usr/share/corebrum/logo.png' "${ROOT}/config/greetd/gtkgreet.css"; then
  echo "FAIL: the login screen does not show the Corebrum logo" >&2
  exit 1
fi
if ! grep -q 'config/brand/logo.png' "${ROOT}/scripts/lib/desktop.sh"; then
  echo "FAIL: the desktop install does not copy the Corebrum logo" >&2
  exit 1
fi
if ! grep -q 'config/brand/agenticros.png' "${ROOT}/scripts/lib/desktop.sh"; then
  echo "FAIL: the desktop install does not copy the AgenticROS mark" >&2
  exit 1
fi
if ! grep -q 'config/brand/ollama.png' "${ROOT}/scripts/lib/desktop.sh"; then
  echo "FAIL: the desktop install does not copy the Ollama mark" >&2
  exit 1
fi
if ! grep -q 'config/brand/ros.png' "${ROOT}/scripts/lib/desktop.sh"; then
  echo "FAIL: the desktop install does not copy the ROS mark" >&2
  exit 1
fi
if ! grep -q 'config/brand/zenoh.png' "${ROOT}/scripts/lib/desktop.sh"; then
  echo "FAIL: the desktop install does not copy the Zenoh mark" >&2
  exit 1
fi
if ! grep -q 'config/brand/realsense.png' "${ROOT}/scripts/lib/desktop.sh"; then
  echo "FAIL: the desktop install does not copy the RealSense mark" >&2
  exit 1
fi
if ! grep -q 'config/brand/agents.png' "${ROOT}/scripts/lib/desktop.sh"; then
  echo "FAIL: the desktop install does not copy the AI Agents mark" >&2
  exit 1
fi
magic="$(od -An -t x1 -N 8 "${ROOT}/config/brand/logo.png" | tr -d ' \n')"
if [[ "$magic" != "89504e470d0a1a0a" ]]; then
  echo "FAIL: config/brand/logo.png is not a PNG" >&2
  exit 1
fi
magic="$(od -An -t x1 -N 8 "${ROOT}/config/brand/agenticros.png" | tr -d ' \n')"
if [[ "$magic" != "89504e470d0a1a0a" ]]; then
  echo "FAIL: config/brand/agenticros.png is not a PNG" >&2
  exit 1
fi
magic="$(od -An -t x1 -N 8 "${ROOT}/config/brand/ollama.png" | tr -d ' \n')"
if [[ "$magic" != "89504e470d0a1a0a" ]]; then
  echo "FAIL: config/brand/ollama.png is not a PNG" >&2
  exit 1
fi
magic="$(od -An -t x1 -N 8 "${ROOT}/config/brand/ros.png" | tr -d ' \n')"
if [[ "$magic" != "89504e470d0a1a0a" ]]; then
  echo "FAIL: config/brand/ros.png is not a PNG" >&2
  exit 1
fi
magic="$(od -An -t x1 -N 8 "${ROOT}/config/brand/zenoh.png" | tr -d ' \n')"
if [[ "$magic" != "89504e470d0a1a0a" ]]; then
  echo "FAIL: config/brand/zenoh.png is not a PNG" >&2
  exit 1
fi
magic="$(od -An -t x1 -N 8 "${ROOT}/config/brand/realsense.png" | tr -d ' \n')"
if [[ "$magic" != "89504e470d0a1a0a" ]]; then
  echo "FAIL: config/brand/realsense.png is not a PNG" >&2
  exit 1
fi
magic="$(od -An -t x1 -N 8 "${ROOT}/config/brand/agents.png" | tr -d ' \n')"
if [[ "$magic" != "89504e470d0a1a0a" ]]; then
  echo "FAIL: config/brand/agents.png is not a PNG" >&2
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
