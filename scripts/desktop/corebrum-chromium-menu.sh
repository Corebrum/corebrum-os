#!/usr/bin/env bash
# Super+Space Chromium entry. Install Ubuntu's Chromium snap, or launch it.
set -euo pipefail

COREBRUM_CHROMIUM_INSTALL_MARK='   install'
COREBRUM_CHROMIUM_BIN="/snap/bin/chromium"

corebrum_chromium_menu_die() {
  printf 'corebrum-chromium-menu: %s\n' "$1" >&2
  exit 1
}

corebrum_chromium_menu_ready() {
  if [[ "${COREBRUM_CHROMIUM_STUB:-0}" == 1 ]]; then
    [[ "${COREBRUM_CHROMIUM_READY:-0}" == 1 ]]
    return
  fi
  [[ -x "$COREBRUM_CHROMIUM_BIN" ]]
}

corebrum_chromium_menu_entry_name() {
  if corebrum_chromium_menu_ready; then
    printf 'Chromium\n'
  else
    printf 'Chromium%s\n' "$COREBRUM_CHROMIUM_INSTALL_MARK"
  fi
}

corebrum_chromium_menu_data_dir() {
  local root="${XDG_RUNTIME_DIR:-/tmp/corebrum-launcher-${UID}}"
  printf '%s\n' "${root}/corebrum"
}

# Papirus ships the Chromium mark as "chromium". The snap logo replaces it
# after install so the row matches the browser that opens.
corebrum_chromium_menu_icon() {
  local icon="/snap/chromium/current/chromium.png"
  if [[ -f "$icon" ]]; then
    printf '%s\n' "$icon"
    return 0
  fi
  printf '%s\n' "chromium"
}

# The Chromium snap also publishes these desktop IDs. Fuzzel lists both beside
# Corebrum's entry: chromium_chromium.desktop launches the browser, and
# chromium_daemon.desktop is named the same but runs /usr/bin/false.
corebrum_chromium_menu_hide_snap_entries() {
  local dir="$1"
  local id
  for id in chromium_chromium.desktop chromium_daemon.desktop; do
    cat >"${dir}/${id}" <<'EOF'
[Desktop Entry]
Type=Application
Name=Chromium Web Browser
Exec=/bin/true
NoDisplay=true
EOF
  done
}

corebrum_chromium_menu_refresh() {
  local dir name icon
  dir="$(corebrum_chromium_menu_data_dir)/applications"
  name="$(corebrum_chromium_menu_entry_name)"
  icon="$(corebrum_chromium_menu_icon)"
  mkdir -p "$dir"
  corebrum_chromium_menu_hide_snap_entries "$dir"
  cat >"${dir}/corebrum-chromium.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=${name}
GenericName=${name}
Comment=Chromium web browser
Exec=/usr/local/bin/corebrum-chromium-menu open
Icon=${icon}
Terminal=false
Categories=Network;WebBrowser;
StartupNotify=false
EOF
}

corebrum_chromium_menu_terminal() {
  local script="$1"
  if [[ "${COREBRUM_CHROMIUM_STUB:-0}" == 1 ]]; then
    printf '%s\n' "$script"
    return 0
  fi
  exec /usr/local/bin/corebrum-terminal bash -c "$script"
}

corebrum_chromium_menu_open() {
  if corebrum_chromium_menu_ready; then
    if [[ "${COREBRUM_CHROMIUM_STUB:-0}" == 1 ]]; then
      printf '%s\n' "$COREBRUM_CHROMIUM_BIN"
      return 0
    fi
    exec "$COREBRUM_CHROMIUM_BIN"
  fi
  corebrum_chromium_menu_terminal "$(cat <<'EOF'
set +e
sudo apt-get update && sudo apt-get install -y chromium-browser snapd && sudo snap install chromium
ec=$?
set -e
printf '\n'
if [ "$ec" -eq 0 ]; then
  printf '%s\n' "Chromium is installed. Press Super+Space and choose Chromium."
else
  printf 'Install failed (%s).\n' "$ec"
fi
read -r -p 'Press Enter to close. '
EOF
)"
}

usage() {
  cat <<'EOF'
Usage: corebrum-chromium-menu refresh|open|entry-name|data-dir
EOF
}

cmd="${1:-}"
case "$cmd" in
  refresh) corebrum_chromium_menu_refresh ;;
  open) corebrum_chromium_menu_open ;;
  entry-name) corebrum_chromium_menu_entry_name ;;
  data-dir) corebrum_chromium_menu_data_dir ;;
  -h | --help | help) usage ;;
  *)
    usage >&2
    exit 1
    ;;
esac
