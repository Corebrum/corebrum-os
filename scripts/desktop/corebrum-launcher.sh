#!/usr/bin/env bash
# Super+Space. Refreshes menu entries together, then opens the window.
set -euo pipefail

# Each refresh rewrites its own desktop files. Running them one after another
# held the menu for several seconds, mostly on agent setup and nvm.
pids=()
/usr/local/bin/corebrum-ros-menu refresh &
pids+=("$!")
/usr/local/bin/corebrum-agenticros-menu refresh &
pids+=("$!")
/usr/local/bin/corebrum-skills-menu refresh &
pids+=("$!")
/usr/local/bin/corebrum-arc-menu refresh &
pids+=("$!")
/usr/local/bin/corebrum-realsense-menu refresh &
pids+=("$!")
/usr/local/bin/corebrum-chromium-menu refresh &
pids+=("$!")
/usr/local/bin/corebrum-ollama-menu refresh &
pids+=("$!")
/usr/local/bin/corebrum-zenoh-fleet-menu refresh &
pids+=("$!")
/usr/local/bin/corebrum-agents-menu refresh &
pids+=("$!")
/usr/local/bin/corebrum-wallpaper-menu refresh &
pids+=("$!")
/usr/local/bin/corebrum-autolock refresh &
pids+=("$!")
/usr/local/bin/corebrum-power-menu refresh &
pids+=("$!")
/usr/local/bin/corebrum-vnc-menu refresh &
pids+=("$!")
/usr/local/bin/corebrum-keys-menu refresh &
pids+=("$!")
/usr/local/bin/corebrum-updates-menu refresh &
pids+=("$!")
refresh_status=0
for pid in "${pids[@]}"; do
  wait "$pid" || refresh_status=1
done
if [[ "$refresh_status" -ne 0 ]]; then
  exit "$refresh_status"
fi
data_dir="$(/usr/local/bin/corebrum-ros-menu data-dir)"
# The Thunar package names its desktop entry "Thunar File Manager". The same
# desktop ID here is listed as Files and is the only copy Fuzzel sees.
mkdir -p "${data_dir}/applications"
cat >"${data_dir}/applications/thunar.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=Files
GenericName=Files
Comment=Browse files
Exec=thunar
Icon=org.xfce.thunar
Terminal=false
Categories=System;FileManager;
StartupNotify=true
EOF
if [[ -n "${XDG_DATA_DIRS:-}" ]]; then
  export XDG_DATA_DIRS="${data_dir}:${XDG_DATA_DIRS}"
else
  export XDG_DATA_DIRS="${data_dir}:/usr/local/share:/usr/share"
fi
# Fuzzel rejects an empty prompt in its ini file, so the blank search field is set here.
# The menu window lists parent entries until the user types. Submenu items such as
# Grok and Gazebo are desktop files with NoDisplay=true, and the window adds them
# only when the typed text matches. Fuzzel remains the fallback and the submenu UI.
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ui="${script_dir}/corebrum-launcher.py"
if [[ ! -f "$ui" ]]; then
  ui=/usr/local/lib/corebrum/corebrum-launcher.py
fi
set +e
python3 "$ui"
status=$?
set -e
if [[ "$status" -eq 2 ]]; then
  exec fuzzel --config /etc/corebrum/fuzzel/fuzzel.ini --prompt ''
fi
exit "$status"
