#!/usr/bin/env bash
# Super+Space shows root groups; typing finds nested items under the active menu.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ui="${ROOT}/scripts/desktop/corebrum-launcher.py"
launcher="${ROOT}/scripts/desktop/corebrum-launcher.sh"
menu_tree="${ROOT}/config/menu/corebrum-menu.json"

if ! grep -q 'background-color: #1c1c1c' "$ui"; then
  echo "FAIL: Super+Space is not using the dark Fuzzel background" >&2
  exit 1
fi
if ! grep -q 'gtk-application-prefer-dark-theme' "$ui"; then
  echo "FAIL: Super+Space does not request the dark GTK theme" >&2
  exit 1
fi
if ! grep -q 'corebrum-launcher.py' "$launcher"; then
  echo "FAIL: Super+Space does not open the search window" >&2
  exit 1
fi
if [[ ! -f "$menu_tree" ]]; then
  echo "FAIL: the Corebrum menu tree is missing" >&2
  exit 1
fi
if ! grep -q 'corebrum-menu.json' "${ROOT}/scripts/lib/desktop.sh"; then
  echo "FAIL: desktop install does not ship the menu tree" >&2
  exit 1
fi
python3 - "$ui" <<'PY'
import pathlib, sys
text = pathlib.Path(sys.argv[1]).read_text()
req = text.find('gi.require_version("Gdk", "3.0")')
imp = text.find("from gi.repository import Gdk, GLib, Gtk")
if req < 0 or imp < 0 or req > imp:
    raise SystemExit("the menu does not request Gdk 3 before importing it")
if "KEY_BackSpace" not in text:
    raise SystemExit("the menu has no Backspace go-back handling")
if "KEY_Right" not in text or "KEY_KP_Right" not in text:
    raise SystemExit("the menu has no Right open-submenu handling")
if "def display_name" not in text or 'f"{row.name} >"' not in text:
    raise SystemExit("navigable rows do not show a > marker")
if "lib.gtk_layer_set_layer(ptr, 3)" not in text:
    raise SystemExit("the menu does not use gtk-layer-shell overlay (layer 3)")
PY
if ! grep -q -- "fuzzel --config /etc/corebrum/fuzzel/fuzzel.ini --prompt ''" "$launcher"; then
  echo "FAIL: Super+Space has no Fuzzel fallback with a blank prompt" >&2
  exit 1
fi
if ! grep -q '^layer=overlay$' "${ROOT}/config/fuzzel/fuzzel.ini"; then
  echo "FAIL: Super+Space fuzzel.ini does not set layer=overlay" >&2
  exit 1
fi

tmp="$(mktemp -d)"
home="${tmp}/home"
share="${tmp}/share"
mkdir -p "${home}/applications" "${share}/applications"
cat >"${share}/applications/corebrum-agents.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=AI Agents
Exec=/usr/local/bin/corebrum-agents-menu open
EOF
cat >"${share}/applications/corebrum-agent-grok.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=Grok CLI   install
Keywords=grok;
Exec=/usr/local/bin/corebrum-agents-menu launch grok
NoDisplay=true
EOF
cat >"${share}/applications/corebrum-agent-default-clear.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=Super+A default: Clear
Exec=/usr/local/bin/corebrum-agents-menu default-clear
NoDisplay=true
EOF
cat >"${share}/applications/corebrum-agent-default-set.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=Super+A default: Set
Exec=/usr/local/bin/corebrum-agents-menu open-set-default
NoDisplay=true
EOF
cat >"${share}/applications/firefox.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=Firefox
Exec=firefox
EOF
cat >"${share}/applications/org.gnome.TextEditor.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=Text Editor
GenericName=Text Editor
Comment=View and edit text files
Keywords=write;notepad;
Exec=gnome-text-editor %U
Icon=org.gnome.TextEditor
Terminal=false
EOF
cat >"${share}/applications/corebrum-ros.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=ROS
Exec=/usr/local/bin/corebrum-ros-menu open
EOF
cat >"${share}/applications/corebrum-ros-tool-gazebo.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=Gazebo   install
Keywords=gazebo;
Exec=/usr/local/bin/corebrum-ros-menu launch gazebo
NoDisplay=true
EOF
cat >"${share}/applications/corebrum-ollama.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=Ollama   install
Keywords=ollama;local;llm
Exec=/usr/local/bin/corebrum-ollama-menu open
EOF
cat >"${share}/applications/corebrum-wallpaper.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=Wallpaper
Exec=/usr/local/bin/corebrum-wallpaper-menu open
EOF
cat >"${share}/applications/corebrum-updates.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=Updates
Exec=/usr/local/bin/corebrum-updates-menu open
EOF
cat >"${share}/applications/corebrum-update-ubuntu.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=Ubuntu
Keywords=ubuntu;update;
Exec=/usr/local/bin/corebrum-updates-menu launch ubuntu
NoDisplay=true
EOF
cat >"${share}/applications/corebrum-power.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=System
Exec=/usr/local/bin/corebrum-power-menu open
EOF
cat >"${share}/applications/corebrum-power-action-reboot.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=Reboot
Keywords=reboot;restart;
Exec=/usr/local/bin/corebrum-power-menu launch reboot
NoDisplay=true
EOF
cat >"${share}/applications/hidden.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=Hidden Tool
NoDisplay=true
Exec=/bin/true
EOF
cat >"${home}/applications/chromium_chromium.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=Chromium Web Browser
NoDisplay=true
Exec=/bin/true
EOF
cat >"${share}/applications/chromium_chromium.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=Chromium Web Browser
Exec=/snap/bin/chromium
Icon=/snap/chromium/current/chromium.png
EOF
cat >"${share}/applications/corebrum-chromium.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=Chromium
Exec=/usr/local/bin/corebrum-chromium-menu open
Icon=chromium
EOF
cat >"${share}/applications/nm-connection-editor.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=Advanced Network Configuration
Exec=nm-connection-editor
EOF
cat >"${home}/applications/nm-connection-editor.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=Network Configuration
Exec=nm-connection-editor
EOF
menu="${tmp}/menu"
mkdir -p "${menu}/applications"
cat >"${menu}/applications/thunar.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=Files
Exec=thunar
EOF
cat >"${menu}/applications/org.gnome.Nautilus.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=Files
NoDisplay=true
EOF
cat >"${share}/applications/org.gnome.Nautilus.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=Files
Exec=nautilus --new-window
Icon=org.gnome.Nautilus
EOF
cat >"${share}/applications/thunar.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=Thunar File Manager
Exec=thunar
EOF

export XDG_DATA_HOME="$home"
export XDG_DATA_DIRS="${menu}:${share}"
export COREBRUM_LAUNCHER_LIST=1
export COREBRUM_MENU_TREE="$menu_tree"
export XDG_CURRENT_DESKTOP=Hyprland

names() {
  cut -f1
}

idle="$(COREBRUM_LAUNCHER_QUERY= python3 "$ui")"
idle_names="$(names <<<"$idle")"
expected=$'Apps >\nLearn >\nAI Agents >\nRobot >\nAppearance >\nSetup >\nUpdates >\nSystem >'
if [[ "$idle_names" != "$expected" ]]; then
  echo "FAIL: the idle menu is not the eight root groups with > markers" >&2
  printf '%s\n' "$idle_names" >&2
  exit 1
fi
if grep -q 'Grok' <<<"$idle" || grep -q 'Gazebo' <<<"$idle" || grep -q 'Firefox' <<<"$idle" || grep -q 'Hidden Tool' <<<"$idle"; then
  echo "FAIL: the idle menu lists a nested or app row" >&2
  printf '%s\n' "$idle" >&2
  exit 1
fi

apps="$(COREBRUM_LAUNCHER_ACTIVE=apps COREBRUM_LAUNCHER_QUERY= python3 "$ui")"
apps_names="$(names <<<"$apps")"
if ! grep -qx 'Firefox' <<<"$apps_names" || ! grep -qx 'Chromium' <<<"$apps_names" || ! grep -qx 'Text Editor' <<<"$apps_names"; then
  echo "FAIL: Apps dropped a normal application" >&2
  printf '%s\n' "$apps_names" >&2
  exit 1
fi
if grep -q ' >' <<<"$apps_names"; then
  echo "FAIL: Apps leaf rows show a submenu marker" >&2
  printf '%s\n' "$apps_names" >&2
  exit 1
fi
if grep -q 'Grok' <<<"$apps" || grep -q 'ROS' <<<"$apps" || grep -q 'Chromium Web Browser' <<<"$apps"; then
  echo "FAIL: Apps listed a claimed or hidden row" >&2
  printf '%s\n' "$apps" >&2
  exit 1
fi
if grep -qx 'Advanced Network Configuration' <<<"$apps_names"; then
  echo "FAIL: Apps still uses Advanced Network Configuration" >&2
  exit 1
fi
if ! grep -qx 'Network Configuration' <<<"$apps_names"; then
  echo "FAIL: Apps dropped Network Configuration" >&2
  printf '%s\n' "$apps_names" >&2
  exit 1
fi
if [[ "$(grep -cx 'Files' <<<"$apps_names")" -ne 1 ]]; then
  echo "FAIL: Apps does not list one Files row" >&2
  printf '%s\n' "$apps_names" >&2
  exit 1
fi
if grep -qx 'Thunar File Manager' <<<"$apps_names"; then
  echo "FAIL: Apps still lists Thunar File Manager" >&2
  exit 1
fi

robot="$(COREBRUM_LAUNCHER_ACTIVE=robot COREBRUM_LAUNCHER_QUERY= python3 "$ui")"
robot_names="$(names <<<"$robot")"
if ! grep -qx 'ROS >' <<<"$robot_names"; then
  echo "FAIL: Robot dropped the ROS submenu marker" >&2
  printf '%s\n' "$robot_names" >&2
  exit 1
fi
if grep -qx 'Ollama   install' <<<"$robot_names" || grep -q 'Ollama' <<<"$robot_names"; then
  echo "FAIL: Robot still lists Ollama; it belongs under AI Agents" >&2
  printf '%s\n' "$robot_names" >&2
  exit 1
fi
if grep -qx 'AI Agents >' <<<"$robot_names"; then
  echo "FAIL: Robot still nests AI Agents; it should be a top-level group" >&2
  printf '%s\n' "$robot_names" >&2
  exit 1
fi

grok="$(COREBRUM_LAUNCHER_QUERY=grok python3 "$ui")"
if ! grep -q $'^Grok CLI   install\tAI Agents$' <<<"$grok"; then
  echo "FAIL: typing grok did not find Grok under AI Agents" >&2
  printf '%s\n' "$grok" >&2
  exit 1
fi
ai="$(COREBRUM_LAUNCHER_ACTIVE=ai-agents-menu COREBRUM_LAUNCHER_QUERY= python3 "$ui")"
ai_first="$(names <<<"$ai" | head -n 1)"
if [[ "$ai_first" != "Super+A default: Clear" ]]; then
  echo "FAIL: AI Agents top group should list default rows first, not a duplicate AI Agents row" >&2
  printf '%s\n' "$ai" >&2
  exit 1
fi
if ! grep -qx 'Ollama   install' <<<"$(names <<<"$ai")"; then
  echo "FAIL: AI Agents does not list Ollama" >&2
  printf '%s\n' "$ai" >&2
  exit 1
fi
ollama="$(COREBRUM_LAUNCHER_QUERY=ollama python3 "$ui")"
if ! grep -q $'^Ollama   install\tAI Agents$' <<<"$ollama"; then
  echo "FAIL: typing ollama did not find Ollama under AI Agents" >&2
  printf '%s\n' "$ollama" >&2
  exit 1
fi
if grep -q 'Gazebo' <<<"$grok"; then
  echo "FAIL: typing grok also listed Gazebo" >&2
  exit 1
fi

notepad="$(COREBRUM_LAUNCHER_QUERY=notepad python3 "$ui")"
if ! grep -q $'^Text Editor\tApps$' <<<"$notepad"; then
  echo "FAIL: typing notepad did not find Text Editor under Apps" >&2
  printf '%s\n' "$notepad" >&2
  exit 1
fi

gazebo="$(COREBRUM_LAUNCHER_QUERY=gazebo python3 "$ui")"
if ! grep -q $'^Gazebo   install\tRobot / ROS$' <<<"$gazebo"; then
  echo "FAIL: typing gazebo did not find Gazebo under Robot / ROS" >&2
  printf '%s\n' "$gazebo" >&2
  exit 1
fi

wallpaper="$(COREBRUM_LAUNCHER_QUERY=wallpaper python3 "$ui")"
if ! grep -qx 'Wallpaper' <<<"$(names <<<"$wallpaper")" && ! grep -q $'^Wallpaper\t' <<<"$wallpaper"; then
  echo "FAIL: typing wallpaper did not find Wallpaper" >&2
  printf '%s\n' "$wallpaper" >&2
  exit 1
fi

updates="$(COREBRUM_LAUNCHER_QUERY=updates python3 "$ui")"
if ! grep -qx 'Updates >' <<<"$(names <<<"$updates")"; then
  echo "FAIL: typing updates did not find Updates with a submenu marker" >&2
  printf '%s\n' "$updates" >&2
  exit 1
fi

ubuntu="$(COREBRUM_LAUNCHER_QUERY=ubuntu python3 "$ui")"
if ! grep -q $'^Ubuntu\tUpdates$' <<<"$ubuntu"; then
  echo "FAIL: typing ubuntu did not find the Updates Ubuntu leaf" >&2
  printf '%s\n' "$ubuntu" >&2
  exit 1
fi

reboot="$(COREBRUM_LAUNCHER_QUERY=reboot python3 "$ui")"
if ! grep -q $'^Reboot\tSystem$' <<<"$reboot"; then
  echo "FAIL: typing reboot did not find Reboot under System" >&2
  printf '%s\n' "$reboot" >&2
  exit 1
fi

icon=""
for candidate in \
  /snap/firefox/current/default256.png \
  /snap/chromium/current/chromium.png \
  /usr/share/icons/Papirus/24x24/categories/firefox.svg
do
  if [[ -f "$candidate" ]]; then
    icon="$candidate"
    break
  fi
done
python3 - "$ui" "$icon" <<'PY'
import importlib.util
import sys
spec = importlib.util.spec_from_file_location("ui", sys.argv[1])
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)
if mod.split_exec("firefox %u") != ["firefox"]:
    raise SystemExit("field codes were not removed from Exec")
if mod.split_exec("/usr/local/bin/corebrum-agents-menu launch grok") != ["/usr/local/bin/corebrum-agents-menu", "launch", "grok"]:
    raise SystemExit("a submenu launch command was not kept")
if mod.load_icon_pixbuf(None, "/no/such/icon.png", 24) is not None:
    raise SystemExit("a missing file icon was loaded")
sample = sys.argv[2]
if sample:
    # This test points XDG_DATA_DIRS at a temp directory. Pixbuf finds its
    # loaders through the system data dirs, so put those back before reading.
    import os
    os.environ["XDG_DATA_DIRS"] = "/usr/local/share:/usr/share"
    pix = mod.load_icon_pixbuf(None, sample, 24)
    if pix is None or pix.get_width() < 1:
        raise SystemExit("a file icon was not loaded")
PY

rm -rf "$tmp"
echo "ok: launcher-search"
