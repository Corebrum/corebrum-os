#!/usr/bin/env bash
# Screen recording. The prompt lists a microphone, a webcam, and RealSense when each is present.
set -euo pipefail

COREBRUM_RECORD_PREVIEW_W=320
COREBRUM_RECORD_PREVIEW_H=180
COREBRUM_RECORD_MARGIN=16
COREBRUM_RECORD_AUDIO_ON=0
COREBRUM_RECORD_WEBCAM_DEVICE=""

corebrum_record_runtime() {
  local root="${XDG_RUNTIME_DIR:-/tmp/corebrum-record-${UID}}"
  mkdir -p "${root}/corebrum"
  printf '%s\n' "${root}/corebrum"
}

corebrum_record_preview_cmd() {
  local here
  if [[ -n "${COREBRUM_CAMERA_PREVIEW:-}" ]]; then
    printf '%s\n' "$COREBRUM_CAMERA_PREVIEW"
    return 0
  fi
  here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  if [[ -f "${here}/corebrum-camera-preview.py" ]]; then
    printf '%s\n' "${here}/corebrum-camera-preview.py"
    return 0
  fi
  printf '%s\n' /usr/local/lib/corebrum/corebrum-camera-preview.py
}

corebrum_record_py_ready() {
  if [[ -n "${COREBRUM_RECORD_SDK+x}" ]]; then
    [[ "$COREBRUM_RECORD_SDK" == 1 ]]
    return
  fi
  # find_spec checks that the module is installed without loading librealsense.
  python3 -c 'import importlib.util,sys; sys.exit(0 if importlib.util.find_spec("pyrealsense2") else 1)' >/dev/null 2>&1
}

corebrum_record_discover() {
  local line audio_found=0 webcam_found=""
  COREBRUM_RECORD_AUDIO_ON=0
  COREBRUM_RECORD_WEBCAM_DEVICE=""
  if [[ -z "${COREBRUM_RECORD_HAS_AUDIO+x}" || -z "${COREBRUM_RECORD_WEBCAM+x}" ]]; then
    if command -v pw-dump >/dev/null 2>&1; then
      while IFS= read -r line; do
        case "$line" in
          audio) audio_found=1 ;;
          /dev/video*) webcam_found="$line" ;;
        esac
      done < <(pw-dump | python3 -c 'import json,re,sys
data = json.load(sys.stdin)
audio = False
webcam = ""
for obj in data:
    props = (obj.get("info") or {}).get("props") or {}
    kind = props.get("media.class") or ""
    desc = props.get("node.description") or ""
    path = props.get("object.path") or ""
    if kind == "Audio/Source":
        audio = True
    elif kind == "Video/Source" and "RealSense" not in desc and re.fullmatch(r"v4l2:/dev/video[0-9]+", path) and not webcam:
        webcam = path[len("v4l2:"):]
if audio:
    print("audio")
if webcam:
    print(webcam)
')
    fi
  fi
  if [[ -n "${COREBRUM_RECORD_HAS_AUDIO+x}" ]]; then
    if [[ "$COREBRUM_RECORD_HAS_AUDIO" == 1 ]]; then
      COREBRUM_RECORD_AUDIO_ON=1
    fi
  else
    COREBRUM_RECORD_AUDIO_ON=$audio_found
  fi
  if [[ -n "${COREBRUM_RECORD_WEBCAM+x}" ]]; then
    COREBRUM_RECORD_WEBCAM_DEVICE="$COREBRUM_RECORD_WEBCAM"
  else
    COREBRUM_RECORD_WEBCAM_DEVICE="$webcam_found"
  fi
}

corebrum_record_menu() {
  local -a rows=("Screen")
  if [[ "$COREBRUM_RECORD_AUDIO_ON" == 1 ]]; then
    rows+=("Screen and audio")
  fi
  if [[ -n "$COREBRUM_RECORD_WEBCAM_DEVICE" ]]; then
    rows+=("Screen and webcam")
    if [[ "$COREBRUM_RECORD_AUDIO_ON" == 1 ]]; then
      rows+=("Screen, webcam, and audio")
    fi
  fi
  if corebrum_record_py_ready; then
    rows+=("Screen and RealSense")
    if [[ "$COREBRUM_RECORD_AUDIO_ON" == 1 ]]; then
      rows+=("Screen, RealSense, and audio")
    fi
  fi
  printf '%s\n' "${rows[@]}"
}

corebrum_record_notify() {
  local message="$1"
  if command -v notify-send >/dev/null 2>&1; then
    notify-send --app-name=Corebrum "Recording" "$message" || true
  else
    printf 'corebrum-record: %s\n' "$message" >&2
  fi
}

corebrum_record_choose() {
  local choice="" lines=()
  if [[ -n "${COREBRUM_RECORD_CHOICE:-}" ]]; then
    printf '%s\n' "$COREBRUM_RECORD_CHOICE"
    return 0
  fi
  mapfile -t lines < <(corebrum_record_menu)
  if [[ "${#lines[@]}" -le 1 ]]; then
    printf '%s\n' "Screen"
    return 0
  fi
  choice="$(printf '%s\n' "${lines[@]}" | fuzzel \
    --config /etc/corebrum/fuzzel/fuzzel.ini \
    --dmenu \
    --prompt 'Record  ' \
    --width 40 \
    --lines "${#lines[@]}")" || return 1
  printf '%s\n' "$choice"
}

corebrum_record_parse_geom() {
  local geom="$1" pos size
  pos="${geom%% *}"
  size="${geom##* }"
  COREBRUM_RECORD_X="${pos%%,*}"
  COREBRUM_RECORD_Y="${pos##*,}"
  COREBRUM_RECORD_W="${size%%x*}"
  COREBRUM_RECORD_H="${size##*x}"
  [[ "$COREBRUM_RECORD_X" =~ ^[0-9]+$ && "$COREBRUM_RECORD_Y" =~ ^[0-9]+$ \
    && "$COREBRUM_RECORD_W" =~ ^[0-9]+$ && "$COREBRUM_RECORD_H" =~ ^[0-9]+$ ]]
}

corebrum_record_area_fits() {
  local geom="$1" need_w need_h
  corebrum_record_parse_geom "$geom" || return 1
  need_w=$((COREBRUM_RECORD_PREVIEW_W + COREBRUM_RECORD_MARGIN * 2))
  need_h=$((COREBRUM_RECORD_PREVIEW_H + COREBRUM_RECORD_MARGIN * 2))
  [[ "$COREBRUM_RECORD_W" -ge "$need_w" && "$COREBRUM_RECORD_H" -ge "$need_h" ]]
}

corebrum_record_sway() {
  command -v swaymsg >/dev/null 2>&1
}

corebrum_record_close_camera_window() {
  local addr
  if corebrum_record_sway; then
    swaymsg '[app_id="corebrum-camera"] kill' >/dev/null 2>&1 || true
    return 0
  fi
  command -v hyprctl >/dev/null 2>&1 || return 0
  addr="$(corebrum_record_camera_address || true)"
  [[ -n "$addr" ]] || return 0
  hyprctl dispatch closewindow address:"$addr" >/dev/null 2>&1 || true
}

corebrum_record_stop_preview() {
  local pidfile pid
  pidfile="$(corebrum_record_runtime)/camera.pid"
  if [[ -f "$pidfile" ]]; then
    pid="$(cat "$pidfile" 2>/dev/null || true)"
    rm -f "$pidfile"
    if [[ -n "$pid" ]]; then
      kill "$pid" 2>/dev/null || true
    fi
  fi
  corebrum_record_close_camera_window
}

corebrum_record_camera_address() {
  hyprctl clients -j | python3 -c 'import json,sys
try:
    clients = json.load(sys.stdin)
except json.JSONDecodeError:
    raise SystemExit(0)
for client in clients:
    if client.get("class") == "corebrum-camera" or client.get("title") == "Camera":
        print(client.get("address", ""))
        break
'
}

corebrum_record_place_preview() {
  local geom="$1" px py addr tries delay i
  corebrum_record_parse_geom "$geom" || return 1
  px=$((COREBRUM_RECORD_X + COREBRUM_RECORD_W - COREBRUM_RECORD_PREVIEW_W - COREBRUM_RECORD_MARGIN))
  py=$((COREBRUM_RECORD_Y + COREBRUM_RECORD_H - COREBRUM_RECORD_PREVIEW_H - COREBRUM_RECORD_MARGIN))
  tries="${COREBRUM_RECORD_PLACE_TRIES:-30}"
  delay="${COREBRUM_RECORD_PLACE_DELAY:-0.1}"
  local pidfile pid
  pidfile="$(corebrum_record_runtime)/camera.pid"
  for ((i = 0; i < tries; i++)); do
    pid="$(cat "$pidfile" 2>/dev/null || true)"
    if [[ -n "$pid" ]] && ! kill -0 "$pid" 2>/dev/null; then
      return 1
    fi
    if corebrum_record_sway; then
      if swaymsg "[app_id=\"corebrum-camera\"] floating enable, border none, sticky enable, move absolute position ${px} px ${py} px, resize set ${COREBRUM_RECORD_PREVIEW_W} px ${COREBRUM_RECORD_PREVIEW_H} px" >/dev/null 2>&1; then
        return 0
      fi
    else
      addr="$(corebrum_record_camera_address || true)"
      if [[ -n "$addr" ]]; then
        hyprctl dispatch movewindowpixel exact "$px" "$py",address:"$addr" >/dev/null
        hyprctl dispatch resizewindowpixel exact "$COREBRUM_RECORD_PREVIEW_W" "$COREBRUM_RECORD_PREVIEW_H",address:"$addr" >/dev/null
        return 0
      fi
    fi
    sleep "$delay"
  done
  return 1
}

corebrum_record_spawn_preview() {
  local cmd="$1"
  shift
  # Replace this shell so the stored pid is the preview, and stop can close it.
  # The desktop install keeps the python file under /usr/local/lib without the executable bit.
  if [[ "$cmd" == *.py ]]; then
    exec python3 "$cmd" "$@"
  fi
  exec "$cmd" "$@"
}

corebrum_record_open_camera() {
  local geom="$1" cmd pidfile err
  shift
  cmd="$(corebrum_record_preview_cmd)"
  pidfile="$(corebrum_record_runtime)/camera.pid"
  err="$(corebrum_record_runtime)/camera.err"
  : >"$err"
  corebrum_record_spawn_preview "$cmd" "$@" >"$err" 2>&1 &
  printf '%s\n' "$!" >"$pidfile"
  sleep "${COREBRUM_RECORD_PREVIEW_GRACE:-0.05}"
  if ! kill -0 "$(cat "$pidfile")" 2>/dev/null; then
    corebrum_record_notify "The camera is already in use. Recording the screen only."
    corebrum_record_stop_preview
    return 1
  fi
  if ! corebrum_record_place_preview "$geom"; then
    if ! kill -0 "$(cat "$pidfile")" 2>/dev/null; then
      corebrum_record_notify "The camera is already in use. Recording the screen only."
    else
      corebrum_record_notify "The camera preview did not open. Recording the screen only."
    fi
    corebrum_record_stop_preview
    return 1
  fi
  return 0
}

corebrum_record_output() {
  printf '%s\n' "${HOME}/Videos/corebrum-$(date +%Y%m%d-%H%M%S).mp4"
}

corebrum_record_run() {
  local geom="$1" audio="$2" file
  file="$(corebrum_record_output)"
  mkdir -p "${HOME}/Videos"
  if [[ "$audio" == 1 ]]; then
    set +e
    wf-recorder -a -g "$geom" -f "$file"
    set -e
    if [[ -s "$file" ]]; then
      return 0
    fi
    rm -f "$file"
    corebrum_record_notify "The microphone was not recorded."
    file="$(corebrum_record_output)"
  fi
  wf-recorder -g "$geom" -f "$file"
}

corebrum_record_start() {
  local choice="" geom="" audio=0 video=""
  corebrum_record_discover
  choice="$(corebrum_record_choose)" || return 0
  [[ -n "$choice" ]] || return 0
  case "$choice" in
    Screen) ;;
    "Screen and audio") audio=1 ;;
    "Screen and webcam") video="webcam" ;;
    "Screen, webcam, and audio") video="webcam"; audio=1 ;;
    "Screen and RealSense") video="realsense" ;;
    "Screen, RealSense, and audio") video="realsense"; audio=1 ;;
    *)
      printf 'corebrum-record: unknown choice %s\n' "$choice" >&2
      return 1
      ;;
  esac
  geom="$(slurp)" || return 0
  [[ -n "$geom" ]] || return 0
  if [[ -n "$video" ]]; then
    if ! corebrum_record_area_fits "$geom"; then
      corebrum_record_notify "The selected area is too small for the camera. Recording the screen only."
    elif [[ "$video" == "webcam" && -z "$COREBRUM_RECORD_WEBCAM_DEVICE" ]]; then
      corebrum_record_notify "The webcam is not available. Recording the screen only."
    elif [[ "$video" == "webcam" ]]; then
      corebrum_record_open_camera "$geom" --v4l2 "$COREBRUM_RECORD_WEBCAM_DEVICE" || true
    else
      corebrum_record_open_camera "$geom" || true
    fi
  fi
  trap corebrum_record_stop_preview EXIT
  corebrum_record_run "$geom" "$audio"
}

corebrum_record_stop() {
  corebrum_record_stop_preview
  pkill -INT wf-recorder 2>/dev/null || true
}

usage() {
  cat <<'EOF'
Usage: corebrum-record start|stop
EOF
}

cmd="${1:-}"
case "$cmd" in
  start) corebrum_record_start ;;
  stop) corebrum_record_stop ;;
  -h | --help | help) usage ;;
  *)
    usage >&2
    exit 1
    ;;
esac
