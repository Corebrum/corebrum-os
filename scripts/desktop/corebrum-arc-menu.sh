#!/usr/bin/env bash
# Super+Space Corebrum Cloud entry. Opens the site in Firefox.
# Refresh only writes the desktop row. It does not install a browser.
set -euo pipefail

COREBRUM_ARC_URL='https://cloud.corebrum.com'

corebrum_arc_data_dir() {
  local root="${XDG_RUNTIME_DIR:-/tmp/corebrum-launcher-${UID}}"
  printf '%s\n' "${root}/corebrum"
}

corebrum_arc_refresh() {
  local dir dest
  dir="$(corebrum_arc_data_dir)/applications"
  dest="${dir}/corebrum-arc.desktop"
  mkdir -p "$dir"
  cat >"$dest" <<'EOF'
[Desktop Entry]
Type=Application
Name=Corebrum Cloud
GenericName=Corebrum Cloud
Comment=Corebrum Cloud
Keywords=arc;cloud;synapse
Exec=/usr/local/bin/corebrum-arc-menu open
Icon=/usr/share/corebrum/icon.png
Terminal=false
Categories=Network;
StartupNotify=false
EOF
}

corebrum_arc_open() {
  if [[ "${COREBRUM_ARC_STUB:-0}" == 1 ]]; then
    printf '%s %s\n' "firefox" "$COREBRUM_ARC_URL"
    return 0
  fi
  exec firefox "$COREBRUM_ARC_URL"
}

usage() {
  cat <<'EOF'
Usage: corebrum-arc-menu refresh|open|data-dir
EOF
}

cmd="${1:-}"
case "$cmd" in
  refresh) corebrum_arc_refresh ;;
  open) corebrum_arc_open ;;
  data-dir) corebrum_arc_data_dir ;;
  -h | --help | help) usage ;;
  *)
    usage >&2
    exit 1
    ;;
esac
