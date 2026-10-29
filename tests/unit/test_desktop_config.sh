#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
conf="${ROOT}/config/sway/config"

require() {
  local needle="$1"
  if ! grep -qF -- "$needle" "$conf"; then
    echo "FAIL: sway config missing ${needle}" >&2
    exit 1
  fi
}

require "gaps inner 4"
require "gaps outer 8"
require "default_border pixel 2"
require "/usr/local/bin/corebrum-autotile"
require "/usr/local/bin/corebrum-terminal"
require "bindsym \$mod+Shift+Return exec firefox"
require "bindsym \$mod+Shift+f exec thunar"
require "bindsym \$mod+Shift+n exec gnome-text-editor"
require "bindsym \$mod+Print exec /usr/local/bin/corebrum-record start"
require "bindsym \$mod+Shift+Print exec /usr/local/bin/corebrum-record stop"
require "bindsym \$mod+p exec"
require "bindsym \$mod+Shift+p exec"
require "bindsym \$mod+Mod1+p exec /usr/local/bin/corebrum-record start"
require "bindsym \$mod+Mod1+Shift+p exec /usr/local/bin/corebrum-record stop"
if grep -q 'wf-recorder' "$conf"; then
  echo "FAIL: recording still calls wf-recorder from the sway config" >&2
  exit 1
fi
if ! grep -q 'app_id="corebrum-camera"' "$conf"; then
  echo "FAIL: the camera preview has no window rule" >&2
  exit 1
fi
require "bindsym \$mod+w kill"
if grep -q 'bindsym $mod+q kill' "$conf"; then
  echo "FAIL: Super+Q still closes the focused window" >&2
  exit 1
fi
require "fullscreen toggle"
require "scratchpad show"
require "/usr/local/bin/corebrum-lock"
require "workspace number 1"
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
if ! grep -q 'Name=Network Configuration' "${ROOT}/scripts/desktop/corebrum-launcher.sh"; then
  echo "FAIL: Super+Space does not rename Advanced Network Configuration" >&2
  exit 1
fi
if ! grep -q 'applications/nm-connection-editor.desktop' "${ROOT}/scripts/desktop/corebrum-launcher.sh"; then
  echo "FAIL: Super+Space does not override the NetworkManager desktop entry" >&2
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
if ! grep -q '/usr/local/bin/corebrum-docs-menu refresh &' "${ROOT}/scripts/desktop/corebrum-launcher.sh"; then
  echo "FAIL: Super+Space does not refresh the Getting Started entry" >&2
  exit 1
fi
if ! grep -q '/usr/local/bin/corebrum-updates-menu refresh &' "${ROOT}/scripts/desktop/corebrum-launcher.sh"; then
  echo "FAIL: Super+Space does not refresh the Updates entry" >&2
  exit 1
fi
if [[ "$(grep -c 'refresh &' "${ROOT}/scripts/desktop/corebrum-launcher.sh")" -lt 15 ]]; then
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
if ! grep -q '/usr/local/bin/corebrum-arc-menu refresh' "${ROOT}/scripts/desktop/corebrum-launcher.sh"; then
  echo "FAIL: Super+Space does not refresh the AgenticROS Cloud entry" >&2
  exit 1
fi
if ! grep -q -- "fuzzel --config /etc/corebrum/fuzzel/fuzzel.ini --prompt ''" "${ROOT}/scripts/desktop/corebrum-launcher.sh"; then
  echo "FAIL: Super+Space launcher does not start Fuzzel with a blank search field" >&2
  exit 1
fi
require "waybar --config /etc/corebrum/waybar/config.json"
require "/usr/local/bin/corebrum-osd volume-up"
require "/usr/local/bin/corebrum-osd brightness-down"
require "/usr/local/bin/corebrum-autolock start"
require 'corebrum/setup-done'
require '/usr/local/bin/corebrum-updates-menu remind'
require '/usr/local/bin/corebrum-setup login'
require 'app_id="corebrum-setup"'
require 'output * bg /usr/share/hypr/wall2.png fill'
require '/usr/local/bin/corebrum-wallpaper-menu restore'
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
if ! grep -q 'exec sway --config' "${ROOT}/scripts/desktop/corebrum-session.sh"; then
  echo "FAIL: the session does not start Sway" >&2
  exit 1
fi
if ! grep -q 'exec sway --unsupported-gpu --config' "${ROOT}/scripts/desktop/corebrum-session.sh"; then
  echo "FAIL: the session does not start Sway on a proprietary NVIDIA driver" >&2
  exit 1
fi
if ! grep -q 'XDG_CURRENT_DESKTOP=sway' "${ROOT}/scripts/desktop/corebrum-session.sh"; then
  echo "FAIL: the session does not name the desktop sway" >&2
  exit 1
fi
if ! grep -q 'swaybg swayidle wlgreet "$locker"' "${ROOT}/scripts/phases/02-desktop.sh"; then
  echo "FAIL: the desktop profile does not consider the Sway packages" >&2
  exit 1
fi
if ! grep -q 'corebrum_lock_package' "${ROOT}/scripts/phases/02-desktop.sh"; then
  echo "FAIL: the desktop profile does not choose the lock program for this Ubuntu release" >&2
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
if ! grep -q 'exec sway --config /etc/corebrum/greetd/sway-config' "${ROOT}/scripts/desktop/corebrum-greetd.sh"; then
  echo "FAIL: the greeter wrapper does not start the greeter Sway" >&2
  exit 1
fi
if ! grep -q 'exec sway --unsupported-gpu --config /etc/corebrum/greetd/sway-config' "${ROOT}/scripts/desktop/corebrum-greetd.sh"; then
  echo "FAIL: the greeter does not start Sway on a proprietary NVIDIA driver" >&2
  exit 1
fi
if ! grep -q 'corebrum-greeter; swaymsg exit' "${ROOT}/config/greetd/sway-config"; then
  echo "FAIL: the greeter Sway does not exit after wlgreet" >&2
  exit 1
fi
if ! grep -q '/usr/share/hypr/wall2.png' "${ROOT}/config/greetd/sway-config"; then
  echo "FAIL: the login screen does not use the Corebrum wallpaper" >&2
  exit 1
fi
if grep -q 'corebrum-login-logo' "${ROOT}/config/greetd/sway-config"; then
  echo "FAIL: the greeter Sway starts a second logo over the login card" >&2
  exit 1
fi
if ! grep -q 'logo.png' "${ROOT}/scripts/desktop/corebrum-login.py"; then
  echo "FAIL: the login card does not draw the Corebrum logo" >&2
  exit 1
fi
if ! grep -q 'placeholder_text("Username")' "${ROOT}/scripts/desktop/corebrum-login.py"; then
  echo "FAIL: the login card has no username field" >&2
  exit 1
fi
if ! grep -q 'placeholder_text("Password")' "${ROOT}/scripts/desktop/corebrum-login.py"; then
  echo "FAIL: the login card has no password field" >&2
  exit 1
fi
if ! python3 "${ROOT}/scripts/desktop/corebrum-login.py" self-check; then
  echo "FAIL: the login card self-check failed" >&2
  exit 1
fi
if ! grep -q '/usr/local/bin/corebrum-login' "${ROOT}/scripts/desktop/corebrum-greeter.sh"; then
  echo "FAIL: the greeter does not start the centered login card" >&2
  exit 1
fi
if ! grep -q 'corebrum-login-logo' "${ROOT}/scripts/desktop/corebrum-greeter.sh"; then
  echo "FAIL: the wlgreet fallback does not show the logo" >&2
  exit 1
fi
if ! grep -q 'gi.require_version("Gdk", "3.0")' "${ROOT}/scripts/desktop/corebrum-login-logo.py"; then
  echo "FAIL: the login logo does not request Gdk 3" >&2
  exit 1
fi
logo_margin="$(python3 "${ROOT}/scripts/desktop/corebrum-login-logo.py" margin 1080)"
if [[ "$logo_margin" != "232" ]]; then
  echo "FAIL: the login logo is not above the card on a 1080p screen (got ${logo_margin})" >&2
  exit 1
fi
logo_margin="$(python3 "${ROOT}/scripts/desktop/corebrum-login-logo.py" margin 400)"
if [[ "$logo_margin" != "16" ]]; then
  echo "FAIL: the login logo does not stay on a short screen (got ${logo_margin})" >&2
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
if ! grep -q -- 'command = "/usr/local/bin/corebrum-session"' "${ROOT}/config/greetd/wlgreet.toml"; then
  echo "FAIL: wlgreet does not start the Corebrum session" >&2
  exit 1
fi
if ! grep -q '/usr/sbin/wlgreet' "${ROOT}/scripts/desktop/corebrum-greeter.sh"; then
  echo "FAIL: the greeter does not run wlgreet" >&2
  exit 1
fi
if ! grep -q -- '--config /etc/corebrum/gtklock/config.ini' "${ROOT}/scripts/desktop/corebrum-lock.sh"; then
  echo "FAIL: the lock command does not use the system gtklock config" >&2
  exit 1
fi
if ! grep -q 'background=/usr/share/hypr/wall2.png' "${ROOT}/config/gtklock/config.ini"; then
  echo "FAIL: the lock screen does not use the Corebrum wallpaper" >&2
  exit 1
fi
if ! grep -q 'entry#input-field' "${ROOT}/config/gtklock/style.css"; then
  echo "FAIL: the lock screen does not style the password field" >&2
  exit 1
fi
if ! grep -q '3d9a8b' "${ROOT}/config/gtklock/style.css"; then
  echo "FAIL: the lock password field is not teal" >&2
  exit 1
fi
if ! grep -q 'file:///usr/share/corebrum/logo.png' "${ROOT}/config/gtklock/style.css"; then
  echo "FAIL: the lock screen does not draw the Corebrum logo" >&2
  exit 1
fi
if ! grep -q 'background-size: 759px 220px' "${ROOT}/config/gtklock/style.css"; then
  echo "FAIL: the lock logo does not keep the artwork aspect" >&2
  exit 1
fi
if ! grep -q 'box#lock-center' "${ROOT}/config/gtklock/style.css"; then
  echo "FAIL: the lock logo is not above the password field" >&2
  exit 1
fi
if ! grep -q 'layout=/etc/corebrum/gtklock/layout.ui' "${ROOT}/config/gtklock/config.ini"; then
  echo "FAIL: the lock screen does not use the Corebrum gtklock layout" >&2
  exit 1
fi
if ! grep -q 'date-format=%A, %d %B %Y' "${ROOT}/config/gtklock/config.ini"; then
  echo "FAIL: the lock date is not the previous format" >&2
  exit 1
fi
if ! grep -q 'font-size: 90pt' "${ROOT}/config/gtklock/style.css"; then
  echo "FAIL: the lock clock is not the previous size" >&2
  exit 1
fi
if ! grep -q 'halign">end' "${ROOT}/config/gtklock/layout.ui"; then
  echo "FAIL: the lock clock is not in the top right" >&2
  exit 1
fi
if ! grep -q 'id="body-revealer"' "${ROOT}/config/gtklock/layout.ui" || ! grep -q 'halign">center' "${ROOT}/config/gtklock/layout.ui"; then
  echo "FAIL: the lock password card is not centered" >&2
  exit 1
fi
if grep -q 'left-attach">1' "${ROOT}/config/gtklock/layout.ui"; then
  echo "FAIL: the lock password field is still beside its label" >&2
  exit 1
fi
if ! grep -q 'placeholder-text">Password' "${ROOT}/config/gtklock/layout.ui"; then
  echo "FAIL: the lock password field has no placeholder" >&2
  exit 1
fi
if ! grep -A8 'id="input-label"' "${ROOT}/config/gtklock/layout.ui" | grep -q 'no-show-all">1'; then
  echo "FAIL: the lock screen still shows the Password label" >&2
  exit 1
fi
if ! grep -q 'valign">start' "${ROOT}/config/gtklock/layout.ui"; then
  echo "FAIL: the lock clock is not at the top of the screen" >&2
  exit 1
fi
if ! grep -q 'config/brand/logo.png' "${ROOT}/scripts/lib/desktop.sh"; then
  echo "FAIL: the desktop install does not copy the Corebrum logo" >&2
  exit 1
fi
if ! grep -q 'config/brand/icon.png' "${ROOT}/scripts/lib/desktop.sh"; then
  echo "FAIL: the desktop install does not copy the Corebrum icon" >&2
  exit 1
fi
magic="$(od -An -t x1 -N 8 "${ROOT}/config/brand/icon.png" | tr -d ' \n')"
if [[ "$magic" != "89504e470d0a1a0a" ]]; then
  echo "FAIL: config/brand/icon.png is not a PNG" >&2
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
if ! grep -q 'config/brand/agents/${name}' "${ROOT}/scripts/lib/desktop.sh"; then
  echo "FAIL: the desktop install does not copy the agent marks" >&2
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
for mark in antigravity claude codex cursor hermes openclaw; do
  magic="$(od -An -t x1 -N 8 "${ROOT}/config/brand/agents/${mark}.png" | tr -d ' \n')"
  if [[ "$magic" != "89504e470d0a1a0a" ]]; then
    echo "FAIL: config/brand/agents/${mark}.png is not a PNG" >&2
    exit 1
  fi
done
magic="$(od -An -t x1 -N 4 "${ROOT}/config/brand/agents/grok.webp" | tr -d ' \n')"
if [[ "$magic" != "52494646" ]]; then
  echo "FAIL: config/brand/agents/grok.webp is not a WebP" >&2
  exit 1
fi
if ! grep -q 'swaybg swayidle wlgreet "$locker"' "${ROOT}/scripts/phases/02-desktop.sh"; then
  echo "FAIL: the desktop profile does not consider swaybg, swayidle, wlgreet, and the lock program" >&2
  exit 1
fi
if ! grep -q 'rm -f /etc/corebrum/sway/swaylock.conf' "${ROOT}/scripts/lib/desktop.sh"; then
  echo "FAIL: the desktop install does not remove the swaylock config" >&2
  exit 1
fi
if grep -q 'config/sway/swaylock.conf"' "${ROOT}/scripts/lib/desktop.sh"; then
  echo "FAIL: the desktop install still copies the swaylock config" >&2
  exit 1
fi
if ! grep -q 'auth include login' "${ROOT}/config/pam.d/gtklock"; then
  echo "FAIL: the gtklock PAM service does not use the login stack" >&2
  exit 1
fi
if ! grep -q 'db20bf27bd5dd01901ea1753c89c170777dd7cf8fca19130cf90f5f4e3fb9633' "${ROOT}/scripts/lib/gtklock.sh"; then
  echo "FAIL: gtklock 4.0.0 is not pinned" >&2
  exit 1
fi
if grep -q 'wlgreet cage' "${ROOT}/scripts/phases/02-desktop.sh"; then
  echo "FAIL: the desktop profile still installs cage for the greeter" >&2
  exit 1
fi
for greet in "${ROOT}/config/greetd/config.toml" "${ROOT}/config/greetd/gtkgreet.toml"; do
  if ! grep -q '^vt = 7$' "$greet"; then
    echo "FAIL: ${greet} should stay on VT 7 so VT 1 remains a text console" >&2
    exit 1
  fi
done

echo "ok: desktop-config"
