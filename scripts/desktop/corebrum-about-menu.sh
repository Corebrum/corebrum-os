#!/usr/bin/env bash
# Super+Space System → About. Refresh writes the desktop row. Open shows the card.
set -euo pipefail

corebrum_about_menu_die() {
  printf 'corebrum-about-menu: %s\n' "$1" >&2
  exit 1
}

corebrum_about_menu_data_dir() {
  local root="${XDG_RUNTIME_DIR:-/tmp/corebrum-launcher-${UID}}"
  printf '%s\n' "${root}/corebrum"
}

corebrum_about_menu_refresh() {
  local dir
  dir="$(corebrum_about_menu_data_dir)/applications"
  mkdir -p "$dir"
  cat >"${dir}/corebrum-about.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=About
GenericName=About
Comment=Hardware, software, uptime, and last update
Keywords=about;info;system info;version;hardware;uptime;
Exec=/usr/local/bin/corebrum-about-menu open
Icon=/usr/share/corebrum/icon.png
Terminal=false
Categories=System;
StartupNotify=false
EOF
}

corebrum_about_menu_open() {
  if [[ "${COREBRUM_ABOUT_STUB:-0}" == 1 ]]; then
    printf 'corebrum-about open\n'
    return 0
  fi
  if [[ -x /usr/local/bin/corebrum-about ]]; then
    exec /usr/local/bin/corebrum-about open
  fi
  corebrum_about_menu_die "corebrum-about is not installed"
}

usage() {
  cat <<'EOF'
Usage: corebrum-about-menu refresh|open|data-dir
EOF
}

cmd="${1:-}"
case "$cmd" in
  refresh) corebrum_about_menu_refresh ;;
  open) corebrum_about_menu_open ;;
  data-dir) corebrum_about_menu_data_dir ;;
  -h | --help | help) usage ;;
  *)
    usage >&2
    exit 1
    ;;
esac
