#!/usr/bin/env bash
# Super+Space Wormhole entry. Install Ubuntu magic-wormhole, then send or receive a file.
set -euo pipefail

COREBRUM_WORMHOLE_INSTALL_MARK='   install'

corebrum_wormhole_die() {
  printf 'corebrum-wormhole-menu: %s\n' "$1" >&2
  exit 1
}

corebrum_wormhole_ready() {
  if [[ "${COREBRUM_WORMHOLE_STUB:-0}" == 1 ]]; then
    [[ "${COREBRUM_WORMHOLE_READY:-0}" == 1 ]]
    return
  fi
  command -v wormhole >/dev/null 2>&1
}

corebrum_wormhole_entry_name() {
  if corebrum_wormhole_ready; then
    printf 'Wormhole\n'
  else
    printf 'Wormhole%s\n' "$COREBRUM_WORMHOLE_INSTALL_MARK"
  fi
}

corebrum_wormhole_data_dir() {
  local root="${XDG_RUNTIME_DIR:-/tmp/corebrum-launcher-${UID}}"
  printf '%s\n' "${root}/corebrum"
}

corebrum_wormhole_refresh() {
  local dir name
  dir="$(corebrum_wormhole_data_dir)/applications"
  name="$(corebrum_wormhole_entry_name)"
  mkdir -p "$dir"
  cat >"${dir}/corebrum-wormhole.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=${name}
GenericName=${name}
Comment=Send a file to another Corebrum machine
Keywords=wormhole;send;receive;files
Exec=/usr/local/bin/corebrum-wormhole-menu open
Icon=document-send
Terminal=false
Categories=Network;FileTransfer;
StartupNotify=false
EOF
}

corebrum_wormhole_terminal() {
  local script="$1"
  if [[ "${COREBRUM_WORMHOLE_STUB:-0}" == 1 ]]; then
    printf '%s\n' "$script"
    return 0
  fi
  exec /usr/local/bin/corebrum-terminal bash -c "$script"
}

corebrum_wormhole_install_script() {
  cat <<'EOF'
set +e
candidate=$(apt-cache policy magic-wormhole | awk '/Candidate:/ { print $2; exit }')
if [ -z "$candidate" ] || [ "$candidate" = "(none)" ]; then
  printf '%s\n' "magic-wormhole is not in this Ubuntu archive."
  printf '\n'
  read -r -p 'Press Enter to close. '
  exit 0
fi
sudo apt-get update && sudo apt-get install -y magic-wormhole
ec=$?
set -e
printf '\n'
if [ "$ec" -eq 0 ]; then
  printf '%s\n' "Wormhole is installed. Press Super+Space and choose Wormhole, then Send or Receive."
else
  printf 'Install failed (%s).\n' "$ec"
fi
read -r -p 'Press Enter to close. '
EOF
}

corebrum_wormhole_send_script() {
  cat <<'EOF'
set +e
read -r -p "File or folder: " path
if [ -z "$path" ]; then
  printf '%s\n' "No path was entered."
  read -r -p "Press Enter to close. "
  exit 0
fi
if [ ! -e "$path" ]; then
  printf 'That path is not on this machine: %s\n' "$path"
  read -r -p "Press Enter to close. "
  exit 1
fi
wormhole send -- "$path"
ec=$?
printf '\n'
if [ "$ec" -ne 0 ]; then
  printf 'Send failed (%s).\n' "$ec"
fi
read -r -p "Press Enter to close. "
EOF
}

corebrum_wormhole_receive_script() {
  cat <<'EOF'
set +e
read -r -p "Code: " code
if [ -z "$code" ]; then
  printf '%s\n' "No code was entered."
  read -r -p "Press Enter to close. "
  exit 0
fi
if [ -d "$HOME/Downloads" ]; then
  cd "$HOME/Downloads" || exit 1
else
  cd "$HOME" || exit 1
fi
wormhole receive -- "$code"
ec=$?
printf '\n'
if [ "$ec" -ne 0 ]; then
  printf 'Receive failed (%s).\n' "$ec"
fi
read -r -p "Press Enter to close. "
EOF
}

corebrum_wormhole_lines() {
  printf 'Send\n'
  printf 'Receive\n'
}

corebrum_wormhole_apply_choice() {
  local choice="$1"
  case "$choice" in
    Send)
      corebrum_wormhole_terminal "$(corebrum_wormhole_send_script)"
      ;;
    Receive)
      corebrum_wormhole_terminal "$(corebrum_wormhole_receive_script)"
      ;;
    *)
      corebrum_wormhole_die "unknown wormhole choice"
      ;;
  esac
}

corebrum_wormhole_open() {
  local choice
  if ! corebrum_wormhole_ready; then
    corebrum_wormhole_terminal "$(corebrum_wormhole_install_script)"
    return 0
  fi
  if [[ "${COREBRUM_WORMHOLE_STUB:-0}" == 1 && -z "${COREBRUM_WORMHOLE_CHOICE:-}" ]]; then
    corebrum_wormhole_lines
    return 0
  fi
  if [[ "${COREBRUM_WORMHOLE_STUB:-0}" == 1 ]]; then
    choice="$COREBRUM_WORMHOLE_CHOICE"
  else
    choice="$(corebrum_wormhole_lines | fuzzel \
      --config /etc/corebrum/fuzzel/fuzzel.ini \
      --dmenu \
      --prompt 'Wormhole  ' \
      --width 32 \
      --lines 2)" || return 0
  fi
  [[ -n "$choice" ]] || return 0
  corebrum_wormhole_apply_choice "$choice"
}

usage() {
  cat <<'EOF'
Usage: corebrum-wormhole-menu refresh|open|entry-name|data-dir
EOF
}

cmd="${1:-}"
case "$cmd" in
  refresh) corebrum_wormhole_refresh ;;
  open) corebrum_wormhole_open ;;
  entry-name) corebrum_wormhole_entry_name ;;
  data-dir) corebrum_wormhole_data_dir ;;
  -h | --help | help) usage ;;
  *)
    usage >&2
    exit 1
    ;;
esac
