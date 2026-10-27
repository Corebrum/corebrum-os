#!/usr/bin/env bash
# Super+Space keeps submenu items out of the idle list and finds them by name.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ui="${ROOT}/scripts/desktop/corebrum-launcher.py"
launcher="${ROOT}/scripts/desktop/corebrum-launcher.sh"

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
if ! grep -q -- "fuzzel --config /etc/corebrum/fuzzel/fuzzel.ini --prompt ''" "$launcher"; then
  echo "FAIL: Super+Space has no Fuzzel fallback with a blank prompt" >&2
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

export XDG_DATA_HOME="$home"
export XDG_DATA_DIRS="$share"
export COREBRUM_LAUNCHER_LIST=1
export XDG_CURRENT_DESKTOP=Hyprland

idle="$(COREBRUM_LAUNCHER_QUERY= python3 "$ui")"
if ! grep -qx 'AI Agents' <<<"$idle" || ! grep -qx 'Firefox' <<<"$idle" || ! grep -qx 'ROS' <<<"$idle" || ! grep -qx 'Chromium' <<<"$idle" || ! grep -qx 'Text Editor' <<<"$idle"; then
  echo "FAIL: the idle menu dropped a parent entry" >&2
  printf '%s\n' "$idle" >&2
  exit 1
fi
if grep -q 'Grok' <<<"$idle" || grep -q 'Gazebo' <<<"$idle" || grep -q 'Hidden Tool' <<<"$idle" || grep -q 'Chromium Web Browser' <<<"$idle"; then
  echo "FAIL: the idle menu lists a submenu item" >&2
  printf '%s\n' "$idle" >&2
  exit 1
fi
if grep -qx 'Advanced Network Configuration' <<<"$idle"; then
  echo "FAIL: the idle menu still uses Advanced Network Configuration" >&2
  exit 1
fi
if ! grep -qx 'Network Configuration' <<<"$idle"; then
  echo "FAIL: the idle menu dropped Network Configuration" >&2
  printf '%s\n' "$idle" >&2
  exit 1
fi
sorted="$(printf '%s\n' "$idle" | LC_ALL=C sort -f)"
if [[ "$idle" != "$sorted" ]]; then
  echo "FAIL: the idle menu is not alphabetical" >&2
  printf '%s\n' "$idle" >&2
  exit 1
fi

grok="$(COREBRUM_LAUNCHER_QUERY=grok python3 "$ui")"
if ! grep -qx 'Grok CLI   install' <<<"$grok"; then
  echo "FAIL: typing grok did not find Grok CLI" >&2
  printf '%s\n' "$grok" >&2
  exit 1
fi
if grep -qx 'Gazebo   install' <<<"$grok"; then
  echo "FAIL: typing grok also listed Gazebo" >&2
  exit 1
fi

notepad="$(COREBRUM_LAUNCHER_QUERY=notepad python3 "$ui")"
if ! grep -qx 'Text Editor' <<<"$notepad"; then
  echo "FAIL: typing notepad did not find Text Editor" >&2
  printf '%s\n' "$notepad" >&2
  exit 1
fi

gazebo="$(COREBRUM_LAUNCHER_QUERY=gazebo python3 "$ui")"
if ! grep -qx 'Gazebo   install' <<<"$gazebo"; then
  echo "FAIL: typing gazebo did not find Gazebo" >&2
  printf '%s\n' "$gazebo" >&2
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
