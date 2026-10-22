#!/usr/bin/env bash
# Super+Space Waypaper entry. Install the wallpaper chooser, or open it.
set -euo pipefail

COREBRUM_WAYPAPER_INSTALL_MARK='   install'
COREBRUM_WAYPAPER_VERSION='2.9'
COREBRUM_WAYPAPER_BIN="${HOME}/.local/bin/waypaper"

corebrum_waypaper_menu_die() {
  printf 'corebrum-waypaper-menu: %s\n' "$1" >&2
  exit 1
}

corebrum_waypaper_menu_ready() {
  if [[ "${COREBRUM_WAYPAPER_STUB:-0}" == 1 ]]; then
    [[ "${COREBRUM_WAYPAPER_READY:-0}" == 1 ]]
    return
  fi
  [[ -x "$COREBRUM_WAYPAPER_BIN" ]]
}

corebrum_waypaper_menu_entry_name() {
  if corebrum_waypaper_menu_ready; then
    printf 'Waypaper\n'
  else
    printf 'Waypaper%s\n' "$COREBRUM_WAYPAPER_INSTALL_MARK"
  fi
}

corebrum_waypaper_menu_data_dir() {
  local root="${XDG_RUNTIME_DIR:-/tmp/corebrum-launcher-${UID}}"
  printf '%s\n' "${root}/corebrum"
}

corebrum_waypaper_menu_refresh() {
  local dir name
  dir="$(corebrum_waypaper_menu_data_dir)/applications"
  name="$(corebrum_waypaper_menu_entry_name)"
  mkdir -p "$dir"
  cat >"${dir}/corebrum-waypaper.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=${name}
GenericName=${name}
Comment=Choose a desktop wallpaper
Exec=/usr/local/bin/corebrum-waypaper-menu open
Icon=preferences-desktop-wallpaper
Terminal=false
Categories=Settings;DesktopSettings;
StartupNotify=false
EOF
}

corebrum_waypaper_menu_terminal() {
  local script="$1"
  if [[ "${COREBRUM_WAYPAPER_STUB:-0}" == 1 ]]; then
    printf '%s\n' "$script"
    return 0
  fi
  exec /usr/local/bin/corebrum-terminal bash -c "$script"
}

corebrum_waypaper_menu_open() {
  if corebrum_waypaper_menu_ready; then
    if [[ "${COREBRUM_WAYPAPER_STUB:-0}" == 1 ]]; then
      printf '%s\n' "$COREBRUM_WAYPAPER_BIN"
      return 0
    fi
    exec "$COREBRUM_WAYPAPER_BIN"
  fi
  corebrum_waypaper_menu_terminal "$(cat <<EOF
set +e
sudo apt-get update && sudo apt-get install -y pipx swaybg python3-gi python3-gi-cairo gir1.2-gtk-3.0
ec=\$?
if [ "\$ec" -eq 0 ]; then
  hash -r
  pipx install --system-site-packages 'waypaper==${COREBRUM_WAYPAPER_VERSION}'
  ec=\$?
fi
set -e
printf '\\n'
if [ "\$ec" -eq 0 ]; then
  printf '%s\\n' "Waypaper is installed. Press Super+Space and choose Waypaper."
else
  printf 'Install failed (%s).\\n' "\$ec"
fi
read -r -p 'Press Enter to close. '
EOF
)"
}

usage() {
  cat <<'EOF'
Usage: corebrum-waypaper-menu refresh|open|entry-name|data-dir
EOF
}

cmd="${1:-}"
case "$cmd" in
  refresh) corebrum_waypaper_menu_refresh ;;
  open) corebrum_waypaper_menu_open ;;
  entry-name) corebrum_waypaper_menu_entry_name ;;
  data-dir) corebrum_waypaper_menu_data_dir ;;
  -h | --help | help) usage ;;
  *)
    usage >&2
    exit 1
    ;;
esac
