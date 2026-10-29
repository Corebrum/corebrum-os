#!/usr/bin/env bash
# Super+Space Getting Started entry. Opens the local guide in Firefox.
# Refresh only writes the desktop row. It does not install a browser.
set -euo pipefail

COREBRUM_DOCS_URL='http://127.0.0.1:8765/getting-started/'

corebrum_docs_data_dir() {
  local root="${XDG_RUNTIME_DIR:-/tmp/corebrum-launcher-${UID}}"
  printf '%s\n' "${root}/corebrum"
}

corebrum_docs_refresh() {
  local dir dest
  dir="$(corebrum_docs_data_dir)/applications"
  dest="${dir}/corebrum-docs.desktop"
  mkdir -p "$dir"
  cat >"$dest" <<'EOF'
[Desktop Entry]
Type=Application
Name=Getting Started
GenericName=Getting Started
Comment=Corebrum user guide
Keywords=docs;help;guide;getting started;documentation
Exec=/usr/local/bin/corebrum-docs-menu open
Icon=/usr/share/corebrum/icon.png
Terminal=false
Categories=Documentation;
StartupNotify=false
EOF
}

corebrum_docs_open() {
  if [[ "${COREBRUM_DOCS_STUB:-0}" == 1 ]]; then
    printf '%s %s\n' "firefox" "$COREBRUM_DOCS_URL"
    return 0
  fi
  exec firefox "$COREBRUM_DOCS_URL"
}

usage() {
  cat <<'EOF'
Usage: corebrum-docs-menu refresh|open|data-dir
EOF
}

cmd="${1:-}"
case "$cmd" in
  refresh) corebrum_docs_refresh ;;
  open) corebrum_docs_open ;;
  data-dir) corebrum_docs_data_dir ;;
  -h | --help | help) usage ;;
  *)
    usage >&2
    exit 1
    ;;
esac
