#!/usr/bin/env bash
# Waybar status for AgenticROS. Click connects or disconnects ARC.
set -euo pipefail

corebrum_agenticros_status_raw() {
  if [[ -n "${COREBRUM_AGENTICROS_STATUS_JSON:-}" ]]; then
    printf '%s\n' "$COREBRUM_AGENTICROS_STATUS_JSON"
    return 0
  fi
  if [[ ! -x /usr/local/bin/agenticros ]]; then
    printf '%s\n' '{"absent":true}'
    return 0
  fi
  /usr/local/bin/agenticros status --json
}

corebrum_agenticros_status_print() {
  corebrum_agenticros_status_raw | python3 -c "$(cat <<'PY'
import json, sys
raw = json.load(sys.stdin)
if raw.get("absent"):
    print(json.dumps({"text": "", "tooltip": "AgenticROS is not installed", "class": "absent"}))
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
    "text": "ARC",
    "tooltip": "\n".join(lines),
    "class": "connected" if connected else "idle",
}))
PY
)"
}

corebrum_agenticros_status_click() {
  local choice
  if [[ ! -x /usr/local/bin/agenticros ]]; then
    return 0
  fi
  if [[ "${COREBRUM_AGENTICROS_STATUS_STUB:-0}" == 1 ]]; then
    printf '%s\n' "Connect ARC" "Disconnect ARC"
    return 0
  fi
  choice="$(printf '%s\n' "Connect ARC" "Disconnect ARC" | fuzzel \
    --config /etc/corebrum/fuzzel/fuzzel.ini \
    --dmenu \
    --prompt 'ARC  ' \
    --width 32 \
    --lines 4)" || return 0
  case "$choice" in
    "Connect ARC")
      if /usr/local/bin/agenticros connect; then
        notify-send "AgenticROS" "Connected to ARC"
      else
        notify-send "AgenticROS" "Could not connect to ARC"
      fi
      ;;
    "Disconnect ARC")
      if /usr/local/bin/agenticros disconnect; then
        notify-send "AgenticROS" "Disconnected from ARC"
      else
        notify-send "AgenticROS" "Could not disconnect from ARC"
      fi
      ;;
  esac
}

cmd="${1:-}"
case "$cmd" in
  click) corebrum_agenticros_status_click ;;
  "" | show) corebrum_agenticros_status_print ;;
  *)
    printf 'Usage: corebrum-agenticros-status [show|click]\n' >&2
    exit 1
    ;;
esac
