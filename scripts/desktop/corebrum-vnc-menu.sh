#!/usr/bin/env bash
# Super+Space remote desktop. Install Ubuntu wayvnc, then share this session.
set -euo pipefail

COREBRUM_VNC_INSTALL_MARK='   install'
COREBRUM_VNC_ON_MARK='   on'
COREBRUM_VNC_PORT=5901
COREBRUM_VNC_PROXY=/usr/local/bin/corebrum-vnc-proxy

corebrum_vnc_die() {
  printf 'corebrum-vnc-menu: %s\n' "$1" >&2
  exit 1
}

corebrum_vnc_ready() {
  if [[ "${COREBRUM_VNC_STUB:-0}" == 1 ]]; then
    [[ "${COREBRUM_VNC_READY:-0}" == 1 ]]
    return
  fi
  command -v wayvnc >/dev/null 2>&1
}

corebrum_vnc_proxy_running() {
  pgrep -f "${COREBRUM_VNC_PROXY} --listen" >/dev/null 2>&1
}

corebrum_vnc_running() {
  if [[ "${COREBRUM_VNC_STUB:-0}" == 1 ]]; then
    [[ "${COREBRUM_VNC_RUNNING:-0}" == 1 ]]
    return
  fi
  pgrep -x wayvnc >/dev/null 2>&1 && corebrum_vnc_proxy_running
}

corebrum_vnc_entry_name() {
  if ! corebrum_vnc_ready; then
    printf 'Remote desktop%s\n' "$COREBRUM_VNC_INSTALL_MARK"
    return 0
  fi
  if corebrum_vnc_running; then
    printf 'Remote desktop%s\n' "$COREBRUM_VNC_ON_MARK"
    return 0
  fi
  printf 'Remote desktop\n'
}

corebrum_vnc_data_dir() {
  local root="${XDG_RUNTIME_DIR:-/tmp/corebrum-launcher-${UID}}"
  printf '%s\n' "${root}/corebrum"
}

corebrum_vnc_runtime_dir() {
  corebrum_vnc_data_dir
}

corebrum_vnc_refresh() {
  local dir name
  dir="$(corebrum_vnc_data_dir)/applications"
  name="$(corebrum_vnc_entry_name)"
  mkdir -p "$dir"
  cat >"${dir}/corebrum-vnc.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=${name}
GenericName=${name}
Comment=Share this desktop with a computer on the same network
Exec=/usr/local/bin/corebrum-vnc-menu open
Icon=preferences-desktop-remote-desktop
Terminal=false
Categories=Network;RemoteAccess;
StartupNotify=false
EOF
}

corebrum_vnc_terminal() {
  local script="$1"
  if [[ "${COREBRUM_VNC_STUB:-0}" == 1 ]]; then
    printf '%s\n' "$script"
    return 0
  fi
  exec /usr/local/bin/corebrum-terminal bash -c "$script"
}

corebrum_vnc_install_script() {
  cat <<'EOF'
set +e
candidate=$(apt-cache policy wayvnc | awk '/Candidate:/ { print $2; exit }')
if [ -z "$candidate" ] || [ "$candidate" = "(none)" ]; then
  printf '%s\n' "wayvnc is not in this Ubuntu archive."
  printf '\n'
  read -r -p 'Press Enter to close. '
  exit 0
fi
sudo apt-get update && sudo apt-get install -y wayvnc
ec=$?
set -e
printf '\n'
if [ "$ec" -eq 0 ]; then
  printf '%s\n' "Remote desktop is installed. Press Super+Space and choose Remote desktop, then Start."
else
  printf 'Install failed (%s).\n' "$ec"
fi
read -r -p 'Press Enter to close. '
EOF
}

corebrum_vnc_addresses() {
  local src rest
  if [[ -n "${COREBRUM_VNC_ADDRESSES+x}" ]]; then
    printf '%s\n' "$COREBRUM_VNC_ADDRESSES"
    return 0
  fi
  if ! command -v ip >/dev/null 2>&1; then
    return 0
  fi
  src="$(ip -4 route get 1.1.1.1 2>/dev/null | awk '{
    for (i = 1; i <= NF; i++) if ($i == "src") { print $(i + 1); exit }
  }')"
  if [[ -n "$src" ]]; then
    printf '%s\n' "$src"
  fi
  while IFS= read -r rest; do
    [[ -n "$rest" && "$rest" != "$src" ]] || continue
    printf '%s\n' "$rest"
  done < <(ip -4 -o addr show scope global 2>/dev/null | awk '{ split($4, a, "/"); print a[1] }')
}

corebrum_vnc_print_addresses() {
  local style="$1" ip any=0
  while IFS= read -r ip; do
    [[ -n "$ip" ]] || continue
    any=1
    case "$style" in
      mac) printf 'vnc://%s\n' "$ip" ;;
      windows) printf '%s::5900\n' "$ip" ;;
      linux) printf '%s:5900\n' "$ip" ;;
    esac
  done < <(corebrum_vnc_addresses)
  if [[ "$any" -eq 0 ]]; then
    printf '%s\n' "This machine has no network address yet."
  fi
}

corebrum_vnc_instructions() {
  local password_file
  password_file="$(corebrum_vnc_runtime_dir)/wayvnc.password"
  if corebrum_vnc_running; then
    printf '%s\n' "Remote desktop is running."
  else
    printf '%s\n' "Remote desktop is not running. Choose Start in this menu first."
  fi
  printf '\n%s\n' "Password"
  if [[ -f "$password_file" ]]; then
    printf 'Password: %s\n' "$(tr -d '[:space:]' <"$password_file")"
  else
    printf '%s\n' "Choose Start first. The password is shown here after it is running."
  fi
  printf '\n%s\n' "On a Mac connected to the same network:"
  printf '%s\n' "1. Open Finder."
  printf '%s\n' "2. Choose Go, then Connect to Server."
  printf '%s\n' "3. Enter one of these addresses and choose Connect."
  printf '\n'
  corebrum_vnc_print_addresses mac
  printf '\n%s\n' "Screen Sharing can connect to the same address without the vnc:// prefix."
  printf '%s\n' "It asks for the password above and does not ask for a name."
  printf '%s\n' "That is not the Mac password."
  printf '%s\n' "The Mac keyboard and pointer control the desktop already on this screen."
  printf '%s\n' "The Command key is Super. Option stays Alt. Command+V pastes."
  printf '%s\n' "Screen Sharing leaves its clipboard commands gray unless the other computer is a Mac."
  printf '\n%s\n' "On Windows:"
  printf '%s\n' "1. Open TigerVNC Viewer."
  printf '%s\n' "2. Enter one of these addresses and choose Connect."
  printf '%s\n' "3. Enter the password above."
  printf '\n'
  corebrum_vnc_print_addresses windows
  printf '\n%s\n' "Type both colons. TigerVNC reads one colon as a display number."
  printf '%s\n' "That password is not the Windows password."
  printf '%s\n' "The Remote Desktop app on Windows does not open this session."
  printf '\n%s\n' "On Linux:"
  printf '%s\n' "1. Open Remmina and create a connection."
  printf '%s\n' "2. Set the protocol to VNC."
  printf '%s\n' "3. Set the server to one of these addresses and choose Connect."
  printf '%s\n' "4. Leave the username empty and enter the password above."
  printf '\n'
  corebrum_vnc_print_addresses linux
  printf '\n%s\n' "That password is not the Linux password."
  printf '%s\n' "TigerVNC on Linux uses the Windows addresses, with both colons."
  printf '%s\n' "Choose Remote desktop, then Stop, when you are done."
}

corebrum_vnc_show() {
  local text
  text="$(corebrum_vnc_instructions)"
  if [[ "${COREBRUM_VNC_STUB:-0}" == 1 ]]; then
    printf '%s\n' "$text"
    return 0
  fi
  COREBRUM_VNC_TEXT="$text" exec /usr/local/bin/corebrum-terminal \
    bash -c 'printf "%s\n\n" "$COREBRUM_VNC_TEXT"; read -r -p "Press Enter to close. "'
}

corebrum_vnc_ensure_password() {
  local dir="$1" file password
  file="${dir}/wayvnc.password"
  if [[ -f "$file" && -z "${COREBRUM_VNC_PASSWORD:-}" ]]; then
    password="$(tr -d '[:space:]' <"$file")"
    if [[ ${#password} -eq 8 ]]; then
      printf '%s\n' "$password"
      return 0
    fi
  fi
  if [[ -n "${COREBRUM_VNC_PASSWORD:-}" ]]; then
    password="$COREBRUM_VNC_PASSWORD"
  else
    # VNC password authentication uses the first 8 characters.
    password="$(openssl rand -hex 4)"
  fi
  printf '%s\n' "$password" >"$file"
  chmod 600 "$file"
  printf '%s\n' "$password"
}

# wayvnc stays on localhost. Screen Sharing talks to corebrum-vnc-proxy,
# which is the process listening on the network.
corebrum_vnc_write_config() {
  local dir="$1"
  mkdir -p "$dir"
  corebrum_vnc_ensure_password "$dir" >/dev/null
  cat >"${dir}/wayvnc.conf" <<EOF
address=127.0.0.1
port=${COREBRUM_VNC_PORT}
EOF
  chmod 600 "${dir}/wayvnc.conf"
}

corebrum_vnc_start() {
  local dir log
  if corebrum_vnc_running; then
    return 0
  fi
  dir="$(corebrum_vnc_runtime_dir)"
  log="${dir}/wayvnc.log"
  corebrum_vnc_write_config "$dir"
  if [[ "${COREBRUM_VNC_STUB:-0}" == 1 ]]; then
    printf 'wayvnc --render-cursor --config %s\n' "${dir}/wayvnc.conf"
    printf '%s --listen 0.0.0.0:5900 --upstream 127.0.0.1:%s --password-file %s\n' \
      "$COREBRUM_VNC_PROXY" "$COREBRUM_VNC_PORT" "${dir}/wayvnc.password"
    return 0
  fi
  if [[ -z "${WAYLAND_DISPLAY:-}" ]]; then
    printf '%s\n' "Remote desktop can only start from the logged-in desktop." >"$log"
    return 1
  fi
  if pgrep -x wayvnc >/dev/null 2>&1; then
    pkill -x wayvnc || true
  fi
  # XDG_CONFIG_HOME keeps wayvnc from reading ~/.config/wayvnc/config.
  setsid --fork -- env \
    XDG_CONFIG_HOME="$dir" \
    wayvnc --render-cursor --config "${dir}/wayvnc.conf" \
    </dev/null >"$log" 2>&1
  local _
  for _ in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do
    if pgrep -x wayvnc >/dev/null 2>&1; then
      break
    fi
    sleep 0.1
  done
  if ! pgrep -x wayvnc >/dev/null 2>&1; then
    return 1
  fi
  setsid --fork -- "$COREBRUM_VNC_PROXY" \
    --listen "0.0.0.0:${COREBRUM_VNC_LISTEN_PORT:-5900}" \
    --upstream "127.0.0.1:${COREBRUM_VNC_PORT}" \
    --password-file "${dir}/wayvnc.password" \
    </dev/null >>"$log" 2>&1
  for _ in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do
    if corebrum_vnc_proxy_running; then
      return 0
    fi
    sleep 0.1
  done
  return 1
}

corebrum_vnc_stop() {
  if [[ "${COREBRUM_VNC_STUB:-0}" == 1 ]]; then
    printf 'stop wayvnc\n'
    return 0
  fi
  if pgrep -x wayvnc >/dev/null 2>&1; then
    pkill -x wayvnc || true
  fi
  if corebrum_vnc_proxy_running; then
    pkill -f "${COREBRUM_VNC_PROXY} --listen" || true
  fi
  local _
  for _ in 1 2 3 4 5 6 7 8 9 10; do
    if ! pgrep -x wayvnc >/dev/null 2>&1 && ! corebrum_vnc_proxy_running; then
      break
    fi
    sleep 0.1
  done
  if command -v notify-send >/dev/null 2>&1; then
    notify-send --app-name=Corebrum --urgency=low "Remote desktop" "Stopped"
  fi
}

corebrum_vnc_show_failure() {
  local log text
  log="$(corebrum_vnc_runtime_dir)/wayvnc.log"
  text="Remote desktop did not start."
  if [[ -f "$log" ]]; then
    text="${text}"$'\n\n'"$(cat "$log")"
  fi
  if [[ "${COREBRUM_VNC_STUB:-0}" == 1 ]]; then
    printf '%s\n' "$text"
    return 0
  fi
  COREBRUM_VNC_TEXT="$text" exec /usr/local/bin/corebrum-terminal \
    bash -c 'printf "%s\n\n" "$COREBRUM_VNC_TEXT"; read -r -p "Press Enter to close. "'
}

corebrum_vnc_lines() {
  if corebrum_vnc_running; then
    printf 'Start%s\n' "$COREBRUM_VNC_ON_MARK"
  else
    printf 'Start\n'
  fi
  printf 'Stop\n'
  printf 'How to connect\n'
}

corebrum_vnc_open() {
  local choice
  if ! corebrum_vnc_ready; then
    corebrum_vnc_terminal "$(corebrum_vnc_install_script)"
    return 0
  fi
  if [[ "${COREBRUM_VNC_STUB:-0}" == 1 && -z "${COREBRUM_VNC_CHOICE:-}" ]]; then
    corebrum_vnc_lines
    return 0
  fi
  if [[ "${COREBRUM_VNC_STUB:-0}" == 1 ]]; then
    choice="$COREBRUM_VNC_CHOICE"
  else
    choice="$(corebrum_vnc_lines | fuzzel \
      --config /etc/corebrum/fuzzel/fuzzel.ini \
      --dmenu \
      --prompt 'Remote desktop  ' \
      --width 48 \
      --lines 3)" || return 0
  fi
  [[ -n "$choice" ]] || return 0
  case "$choice" in
    Start | Start"$COREBRUM_VNC_ON_MARK")
      if corebrum_vnc_start; then
        if [[ "${COREBRUM_VNC_STUB:-0}" == 1 ]]; then
          COREBRUM_VNC_RUNNING=1
        fi
        corebrum_vnc_show
      else
        corebrum_vnc_show_failure
      fi
      ;;
    Stop)
      corebrum_vnc_stop
      ;;
    "How to connect")
      corebrum_vnc_show
      ;;
    *)
      corebrum_vnc_die "unknown remote desktop choice"
      ;;
  esac
}

usage() {
  cat <<'EOF'
Usage: corebrum-vnc-menu refresh|open|entry-name|data-dir|serve
EOF
}

cmd="${1:-}"
case "$cmd" in
  refresh) corebrum_vnc_refresh ;;
  open) corebrum_vnc_open ;;
  entry-name) corebrum_vnc_entry_name ;;
  data-dir) corebrum_vnc_data_dir ;;
  serve)
    corebrum_vnc_start
    corebrum_vnc_instructions
    ;;
  -h | --help | help) usage ;;
  *)
    usage >&2
    exit 1
    ;;
esac
