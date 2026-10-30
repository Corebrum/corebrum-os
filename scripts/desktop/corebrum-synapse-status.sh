#!/usr/bin/env bash
# Waybar status for Corebrum Synapse. Click connects or disconnects ARC.
set -euo pipefail

corebrum_synapse_status_raw() {
  if [[ -n "${COREBRUM_SYNAPSE_STATUS_JSON:-}" ]]; then
    printf '%s\n' "$COREBRUM_SYNAPSE_STATUS_JSON"
    return 0
  fi
  if [[ ! -x /usr/local/bin/synapse ]]; then
    printf '%s\n' '{"absent":true}'
    return 0
  fi
  /usr/local/bin/synapse status --json
}

corebrum_synapse_status_print() {
  corebrum_synapse_status_raw | python3 -c "$(cat <<'PY'
import json, sys
raw = json.load(sys.stdin)
if raw.get("absent"):
    print(json.dumps({"text": "", "tooltip": "Corebrum Synapse is not installed", "class": "absent"}))
    raise SystemExit
lines = []
connected = False
for item in raw.get("hardware", []) + raw.get("components", []):
    name = str(item.get("name", ""))
    running = bool(item.get("running"))
    if name == "comms":
        connected = running
    state = "running" if running else "stopped"
    lines.append(f"{name}: {state}")
gateway = "running" if raw.get("openclawGatewayActive") else "stopped"
lines.append(f"openclaw: {gateway}")
print(json.dumps({
    "text": "Cloud",
    "tooltip": "\n".join(lines),
    "class": "connected" if connected else "idle",
}))
PY
)"
}

corebrum_synapse_status_click() {
  local choice
  if [[ ! -x /usr/local/bin/synapse ]]; then
    return 0
  fi
  if [[ "${COREBRUM_SYNAPSE_STATUS_STUB:-0}" == 1 ]]; then
    printf '%s\n' "Connect Cloud" "Disconnect Cloud"
    return 0
  fi
  choice="$(printf '%s\n' "Connect Cloud" "Disconnect Cloud" | fuzzel \
    --config /etc/corebrum/fuzzel/fuzzel.ini \
    --dmenu \
    --prompt 'Cloud ' \
    --width 32 \
    --lines 4)" || return 0
  case "$choice" in
    "Connect Cloud")
      if /usr/local/bin/synapse connect; then
        notify-send "Corebrum Synapse" "Connected to Corebrum Cloud"
      else
        notify-send "Corebrum Synapse" "Could not connect to Corebrum Cloud"
      fi
      ;;
    "Disconnect Cloud")
      if /usr/local/bin/synapse disconnect; then
        notify-send "Corebrum Synapse" "Disconnected from Corebrum Cloud"
      else
        notify-send "Corebrum Synapse" "Could not disconnect from Corebrum Cloud"
      fi
      ;;
  esac
}

cmd="${1:-}"
case "$cmd" in
  click) corebrum_synapse_status_click ;;
  "" | show) corebrum_synapse_status_print ;;
  *)
    printf 'Usage: corebrum-synapse-status [show|click]\n' >&2
    exit 1
    ;;
esac
