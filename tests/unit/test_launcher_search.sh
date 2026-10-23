#!/usr/bin/env bash
# Super+Space keeps submenu items out of the idle list and finds them by name.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ui="${ROOT}/scripts/desktop/corebrum-launcher.py"
launcher="${ROOT}/scripts/desktop/corebrum-launcher.sh"

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

export XDG_DATA_HOME="$home"
export XDG_DATA_DIRS="$share"
export COREBRUM_LAUNCHER_LIST=1
unset XDG_CURRENT_DESKTOP

idle="$(COREBRUM_LAUNCHER_QUERY= python3 "$ui")"
if ! grep -qx 'AI Agents' <<<"$idle" || ! grep -qx 'Firefox' <<<"$idle" || ! grep -qx 'ROS' <<<"$idle"; then
  echo "FAIL: the idle menu dropped a parent entry" >&2
  printf '%s\n' "$idle" >&2
  exit 1
fi
if grep -q 'Grok' <<<"$idle" || grep -q 'Gazebo' <<<"$idle" || grep -q 'Hidden Tool' <<<"$idle"; then
  echo "FAIL: the idle menu lists a submenu item" >&2
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

gazebo="$(COREBRUM_LAUNCHER_QUERY=gazebo python3 "$ui")"
if ! grep -qx 'Gazebo   install' <<<"$gazebo"; then
  echo "FAIL: typing gazebo did not find Gazebo" >&2
  printf '%s\n' "$gazebo" >&2
  exit 1
fi

python3 - "$ui" <<'PY'
import importlib.util
import sys
spec = importlib.util.spec_from_file_location("ui", sys.argv[1])
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)
if mod.split_exec("firefox %u") != ["firefox"]:
    raise SystemExit("field codes were not removed from Exec")
if mod.split_exec("/usr/local/bin/corebrum-agents-menu launch grok") != ["/usr/local/bin/corebrum-agents-menu", "launch", "grok"]:
    raise SystemExit("a submenu launch command was not kept")
PY

rm -rf "$tmp"
echo "ok: launcher-search"
