#!/usr/bin/env bash
# Super+Space Corebrum Cloud. Guided Sign in → Register → Connect, plus the site.
# Refresh only writes the desktop row. It does not install a browser or Synapse.
set -euo pipefail

COREBRUM_ARC_URL='https://cloud.corebrum.com'

corebrum_arc_die() {
  printf 'corebrum-arc-menu: %s\n' "$1" >&2
  exit 1
}

corebrum_arc_data_dir() {
  local root="${XDG_RUNTIME_DIR:-/tmp/corebrum-launcher-${UID}}"
  printf '%s\n' "${root}/corebrum"
}

corebrum_arc_synapse_ready() {
  if [[ "${COREBRUM_ARC_STUB:-0}" == 1 ]]; then
    [[ "${COREBRUM_ARC_SYNAPSE:-0}" == 1 ]]
    return
  fi
  [[ -x /usr/local/bin/synapse && -f "${HOME}/.synapse/config.json" ]]
}

corebrum_arc_configstore() {
  if [[ -n "${COREBRUM_ARC_CONFIGSTORE:-}" ]]; then
    printf '%s\n' "$COREBRUM_ARC_CONFIGSTORE"
    return 0
  fi
  printf '%s\n' "${XDG_CONFIG_HOME:-${HOME}/.config}/configstore/synapse.json"
}

# Local only: API_TOKEN presence. Does not call the network or print the token.
corebrum_arc_has_token() {
  local store
  if [[ "${COREBRUM_ARC_STUB:-0}" == 1 ]]; then
    [[ "${COREBRUM_ARC_TOKEN:-0}" == 1 ]]
    return
  fi
  store="$(corebrum_arc_configstore)"
  [[ -f "$store" ]] || return 1
  python3 - "$store" <<'PY'
import json, sys
path = sys.argv[1]
try:
    data = json.load(open(path, encoding="utf-8"))
except Exception:
    raise SystemExit(1)
token = data.get("API_TOKEN")
raise SystemExit(0 if isinstance(token, str) and token.strip() else 1)
PY
}

corebrum_arc_status_raw() {
  if [[ -n "${COREBRUM_ARC_STATUS_JSON:-}" ]]; then
    printf '%s\n' "$COREBRUM_ARC_STATUS_JSON"
    return 0
  fi
  if [[ ! -x /usr/local/bin/synapse ]]; then
    printf '%s\n' '{"absent":true}'
    return 0
  fi
  /usr/local/bin/synapse status --json 2>/dev/null || printf '%s\n' '{}'
}

corebrum_arc_connected() {
  local raw
  if [[ "${COREBRUM_ARC_STUB:-0}" == 1 ]]; then
    [[ "${COREBRUM_ARC_CONNECTED:-0}" == 1 ]]
    return
  fi
  raw="$(corebrum_arc_status_raw)"
  printf '%s\n' "$raw" | python3 -c "$(cat <<'PY'
import json, sys
blob = sys.stdin.read()
raw = None
try:
    raw = json.loads(blob)
except json.JSONDecodeError:
    decoder = json.JSONDecoder()
    for index, char in enumerate(blob):
        if char != "{":
            continue
        try:
            raw, _end = decoder.raw_decode(blob[index:])
            break
        except json.JSONDecodeError:
            raw = None
if not isinstance(raw, dict) or raw.get("absent"):
    raise SystemExit(1)
for item in list(raw.get("hardware") or []) + list(raw.get("components") or []):
    if isinstance(item, dict) and item.get("name") == "comms" and item.get("running"):
        raise SystemExit(0)
raise SystemExit(1)
PY
)"
}

corebrum_arc_status_label() {
  if ! corebrum_arc_synapse_ready; then
    printf 'Status: Synapse not installed\n'
    return 0
  fi
  if corebrum_arc_connected; then
    printf 'Status: connected\n'
    return 0
  fi
  if corebrum_arc_has_token; then
    printf 'Status: signed in, not connected\n'
    return 0
  fi
  printf 'Status: needs sign-in\n'
}

corebrum_arc_actions() {
  cat <<'EOF'
setup|Set up
sign-in|Sign in
register|Register this robot
connect|Connect
disconnect|Disconnect
whoami|Account status
website|Open website
EOF
}

corebrum_arc_labels() {
  local slug label
  corebrum_arc_status_label
  if ! corebrum_arc_synapse_ready; then
    printf 'Install Corebrum Synapse\n'
    printf 'Open website\n'
    return 0
  fi
  while IFS='|' read -r slug label; do
    [[ -n "$slug" ]] || continue
    printf '%s\n' "$label"
  done < <(corebrum_arc_actions)
}

corebrum_arc_clear_actions() {
  local dir="$1" file
  shopt -s nullglob
  for file in "${dir}"/corebrum-arc-action-*.desktop; do
    rm -f "$file"
  done
  shopt -u nullglob
}

corebrum_arc_write_actions() {
  local dir="$1" slug label
  corebrum_arc_clear_actions "$dir"
  while IFS='|' read -r slug label; do
    [[ "$slug" =~ ^[a-z0-9-]+$ ]] || corebrum_arc_die "invalid action id: ${slug}"
    cat >"${dir}/corebrum-arc-action-${slug}.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Cloud: ${label}
GenericName=Cloud: ${label}
Keywords=arc;cloud;synapse;${slug};${label};
Comment=Corebrum Cloud
Exec=/usr/local/bin/corebrum-arc-menu launch ${slug}
Icon=/usr/share/corebrum/icon.png
Terminal=false
Categories=Network;
StartupNotify=false
NoDisplay=true
EOF
  done < <(corebrum_arc_actions)
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
  corebrum_arc_write_actions "$dir"
}

corebrum_arc_terminal() {
  local script="$1"
  if [[ "${COREBRUM_ARC_STUB:-0}" == 1 ]]; then
    printf '%s\n' "$script"
    return 0
  fi
  exec /usr/local/bin/corebrum-terminal bash --login -c "$script"
}

corebrum_arc_notify() {
  local title="$1" body="$2"
  if [[ "${COREBRUM_ARC_STUB:-0}" == 1 ]]; then
    printf '%s: %s\n' "$title" "$body"
    return 0
  fi
  if command -v notify-send >/dev/null 2>&1; then
    notify-send "$title" "$body" || true
  fi
}

corebrum_arc_open_website() {
  if [[ "${COREBRUM_ARC_STUB:-0}" == 1 ]]; then
    printf '%s %s\n' "firefox" "$COREBRUM_ARC_URL"
    return 0
  fi
  if ! command -v firefox >/dev/null 2>&1; then
    corebrum_arc_notify "Corebrum Cloud" "Firefox is not installed"
    return 1
  fi
  exec firefox "$COREBRUM_ARC_URL"
}

corebrum_arc_setup_script() {
  cat <<'EOF'
set +e
if [ ! -x /usr/local/bin/synapse ] || [ ! -f "$HOME/.synapse/config.json" ]; then
  printf '%s\n' "Corebrum Synapse is not installed on this machine."
  printf '%s\n' "Press Super+Space, open Robot, then Corebrum Synapse to install it."
  printf '\n'
  read -r -p 'Press Enter to close. '
  exit 0
fi
printf '%s\n' "Corebrum Cloud setup"
printf '%s\n' "This walks Sign in, then Register this robot, then Connect."
printf '%s\n' "A browser-only sign-in on cloud.corebrum.com does not put a token on this robot."
printf '\n'
printf '%s\n' "=== Sign in ==="
synapse login
ec=$?
if [ "$ec" -ne 0 ]; then
  printf '\nSign in failed (%s).\n' "$ec"
  read -r -p 'Press Enter to close. '
  exit "$ec"
fi
printf '\n'
printf '%s\n' "=== Register this robot ==="
synapse register
ec=$?
if [ "$ec" -ne 0 ]; then
  printf '\nRegister failed (%s).\n' "$ec"
  read -r -p 'Press Enter to close. '
  exit "$ec"
fi
printf '\n'
printf '%s\n' "=== Connect ==="
synapse connect
ec=$?
printf '\n'
if [ "$ec" -eq 0 ]; then
  printf '%s\n' "Connected. The Waybar Cloud chip should show connected."
  printf '%s\n' "Open website still opens cloud.corebrum.com in Firefox."
else
  printf 'Connect failed (%s).\n' "$ec"
fi
printf '\n'
synapse whoami || true
printf '\n'
read -r -p 'Press Enter to close. '
EOF
}

corebrum_arc_run() {
  local choice="$1"
  case "$choice" in
    Status:*)
      if [[ "${COREBRUM_ARC_STUB:-0}" == 1 ]]; then
        printf '%s\n' "$choice"
        return 0
      fi
      corebrum_arc_notify "Corebrum Cloud" "${choice#Status: }"
      ;;
    "Install Corebrum Synapse")
      if [[ "${COREBRUM_ARC_STUB:-0}" == 1 ]]; then
        printf 'corebrum-synapse-menu open\n'
        return 0
      fi
      if [[ -x /usr/local/bin/corebrum-synapse-menu ]]; then
        exec /usr/local/bin/corebrum-synapse-menu open
      fi
      corebrum_arc_notify "Corebrum Cloud" "Corebrum Synapse is not installed"
      ;;
    "Set up" | "Set up Cloud")
      corebrum_arc_terminal "$(corebrum_arc_setup_script)"
      ;;
    "Sign in")
      corebrum_arc_terminal "synapse login"
      ;;
    "Register this robot")
      corebrum_arc_terminal "synapse register"
      ;;
    "Connect")
      if [[ "${COREBRUM_ARC_STUB:-0}" == 1 ]]; then
        printf 'synapse connect\n'
        return 0
      fi
      if /usr/local/bin/synapse connect; then
        corebrum_arc_notify "Corebrum Synapse" "Connected to Corebrum Cloud"
      else
        corebrum_arc_notify "Corebrum Synapse" "Could not connect to Corebrum Cloud"
      fi
      ;;
    "Disconnect")
      if [[ "${COREBRUM_ARC_STUB:-0}" == 1 ]]; then
        printf 'synapse disconnect\n'
        return 0
      fi
      if /usr/local/bin/synapse disconnect; then
        corebrum_arc_notify "Corebrum Synapse" "Disconnected from Corebrum Cloud"
      else
        corebrum_arc_notify "Corebrum Synapse" "Could not disconnect from Corebrum Cloud"
      fi
      ;;
    "Account status")
      corebrum_arc_terminal "synapse whoami; printf '\\n'; read -r -p 'Press Enter to close. '"
      ;;
    "Open website")
      corebrum_arc_open_website
      ;;
    *)
      corebrum_arc_die "unknown Corebrum Cloud menu choice"
      ;;
  esac
}

corebrum_arc_open() {
  local choice
  if [[ "${COREBRUM_ARC_STUB:-0}" == 1 && -z "${COREBRUM_ARC_CHOICE:-}" ]]; then
    corebrum_arc_labels
    return 0
  fi
  if [[ "${COREBRUM_ARC_STUB:-0}" == 1 ]]; then
    choice="$COREBRUM_ARC_CHOICE"
  else
    choice="$(corebrum_arc_labels | fuzzel \
      --config /etc/corebrum/fuzzel/fuzzel.ini \
      --dmenu \
      --prompt 'Corebrum Cloud  ' \
      --width 48 \
      --lines 12)" || return 0
  fi
  [[ -n "$choice" ]] || return 0
  corebrum_arc_run "$choice"
}

corebrum_arc_launch_id() {
  local id="$1" slug label
  [[ "$id" =~ ^[a-z0-9-]+$ ]] || corebrum_arc_die "invalid Corebrum Cloud action"
  while IFS='|' read -r slug label; do
    if [[ "$slug" == "$id" ]]; then
      corebrum_arc_run "$label"
      return 0
    fi
  done < <(corebrum_arc_actions)
  corebrum_arc_die "unknown Corebrum Cloud action ${id}"
}

usage() {
  cat <<'EOF'
Usage: corebrum-arc-menu refresh|open|launch ID|labels|status|data-dir
EOF
}

cmd="${1:-}"
case "$cmd" in
  refresh) corebrum_arc_refresh ;;
  open) corebrum_arc_open ;;
  launch) corebrum_arc_launch_id "${2:-}" ;;
  labels) corebrum_arc_labels ;;
  status) corebrum_arc_status_label ;;
  data-dir) corebrum_arc_data_dir ;;
  -h | --help | help) usage ;;
  *)
    usage >&2
    exit 1
    ;;
esac
