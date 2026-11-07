#!/usr/bin/env bash
# Screen recording. The prompt lists a microphone, a webcam, and RealSense when each is present.
set -euo pipefail

# Sway keybindings may not set this; start and stop must share the same paths.
if [[ -z "${HOME:-}" ]]; then
  HOME="$(getent passwd "$(id -u)" | cut -d: -f6)"
  export HOME
fi
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"

corebrum_record_preview_ok_file() {
  printf '%s\n' "$(corebrum_record_session_dir)/preview.ok"
}

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

corebrum_record_session_dir() {
  # Start runs under the login shell; stop often comes from a Sway keybind without
  # XDG_STATE_HOME. Always anchor coordination files under the account home.
  local home="${HOME:-}"
  if [[ -z "$home" ]]; then
    home="$(getent passwd "$(id -u)" | cut -d: -f6)"
  fi
  local root="${home}/.local/state/corebrum"
  mkdir -p "$root"
  printf '%s\n' "$root"
}

corebrum_record_capturing_file() {
  printf '%s\n' "$(corebrum_record_session_dir)/recording.capturing"
}

corebrum_record_path_file() {
  printf '%s\n' "$(corebrum_record_session_dir)/recording.path"
}

corebrum_record_wf_pid_file() {
  printf '%s\n' "$(corebrum_record_session_dir)/wf-recorder.pid"
}

corebrum_record_start_pid_file() {
  printf '%s\n' "$(corebrum_record_session_dir)/recording.start.pid"
}

corebrum_record_stop_request_file() {
  printf '%s\n' "$(corebrum_record_session_dir)/recording.stop"
}

corebrum_record_log() {
  printf '%s %s\n' "$(date -Iseconds)" "$*" >>"$(corebrum_record_session_dir)/record.log" 2>/dev/null || true
}

corebrum_record_note_path() {
  printf '%s\n' "$1" >"$(corebrum_record_path_file)"
}

corebrum_record_recorder_running() {
  pgrep -x wf-recorder >/dev/null 2>&1 \
    || pgrep -f '[w]f-recorder' >/dev/null 2>&1
}

corebrum_record_wf_pid_live() {
  local pid=""
  pid="$(cat "$(corebrum_record_wf_pid_file)" 2>/dev/null || true)"
  [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null
}

corebrum_record_capture_active() {
  [[ -f "$(corebrum_record_capturing_file)" ]] && return 0
  corebrum_record_recorder_running || corebrum_record_wf_pid_live
}

corebrum_record_stop_recorder() {
  local pidfile pid i
  pidfile="$(corebrum_record_wf_pid_file)"
  pid="$(cat "$pidfile" 2>/dev/null || true)"
  if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
    kill -INT "$pid" 2>/dev/null || true
  fi
  if corebrum_record_recorder_running; then
    pkill -INT -x wf-recorder 2>/dev/null || true
  fi
  for ((i = 0; i < 120; i++)); do
    if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
      :
    elif ! corebrum_record_recorder_running; then
      break
    fi
    sleep 0.1
  done
  if corebrum_record_recorder_running; then
    pkill -TERM -x wf-recorder 2>/dev/null || true
    sleep 1
  fi
  if corebrum_record_recorder_running; then
    pkill -KILL -x wf-recorder 2>/dev/null || true
  fi
  if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
    kill -TERM "$pid" 2>/dev/null || true
    sleep 0.5
    kill -0 "$pid" 2>/dev/null && kill -KILL "$pid" 2>/dev/null || true
  fi
  rm -f "$pidfile"
}

corebrum_record_stop_wanted() {
  [[ -f "$(corebrum_record_stop_request_file)" ]]
}

corebrum_record_clear_stop_request() {
  rm -f "$(corebrum_record_stop_request_file)"
}

corebrum_record_on_stop_signal() {
  if ! corebrum_record_capture_active; then
    corebrum_record_clear_stop_request
    corebrum_record_log "stop signal ignored (not capturing)"
    return 0
  fi
  touch "$(corebrum_record_stop_request_file)"
  corebrum_record_stop_recorder
}

corebrum_record_request_stop() {
  local close_preview="${1:-0}"
  corebrum_record_log "stop requested (ppid=${PPID:-?} uid=$(id -u))"
  if ! corebrum_record_capture_active; then
    corebrum_record_clear_stop_request
    corebrum_record_log "stop ignored (not capturing)"
    if corebrum_record_setup_active; then
      corebrum_record_notify "Still starting. Wait for Recording, then press $(corebrum_record_stop_keys) to stop."
    fi
    if [[ "$close_preview" == 1 ]] && ! corebrum_record_setup_active; then
      corebrum_record_stop_preview
    fi
    return 0
  fi
  touch "$(corebrum_record_stop_request_file)"
  local sp=""
  sp="$(cat "$(corebrum_record_start_pid_file)" 2>/dev/null || true)"
  if [[ -n "$sp" ]] && kill -0 "$sp" 2>/dev/null; then
    kill -USR1 "$sp" 2>/dev/null || true
  fi
  corebrum_record_stop_recorder
  if [[ "$close_preview" == 1 ]]; then
    corebrum_record_stop_preview
  fi
}

corebrum_record_setup_active() {
  corebrum_record_capture_active && return 1
  local sp=""
  sp="$(cat "$(corebrum_record_start_pid_file)" 2>/dev/null || true)"
  [[ -n "$sp" ]] && kill -0 "$sp" 2>/dev/null
}

corebrum_record_stop_keys() {
  printf '%s' "Super+Alt+Shift+P"
}

corebrum_record_start_session_end() {
  rm -f "$(corebrum_record_start_pid_file)"
}

corebrum_record_file_playable() {
  local file="$1"
  [[ -f "$file" && -s "$file" ]] || return 1
  if [[ "${COREBRUM_RECORD_NO_FFPROBE:-0}" == 1 ]]; then
    return 0
  fi
  command -v ffprobe >/dev/null 2>&1 || return 1
  ffprobe -v error "$file" >/dev/null 2>&1
}

corebrum_record_has_audio_stream() {
  local file="$1"
  [[ "${COREBRUM_RECORD_NO_FFPROBE:-0}" == 1 ]] && return 1
  command -v ffprobe >/dev/null 2>&1 || return 1
  ffprobe -v error -select_streams a -show_entries stream=codec_type \
    -of csv=p=0 "$file" 2>/dev/null | grep -qxF audio
}

corebrum_record_has_usable_audio() {
  local file="$1" br
  corebrum_record_has_audio_stream "$file" || return 1
  br="$(ffprobe -v error -select_streams a:0 -show_entries stream=bit_rate \
    -of csv=p=0 "$file" 2>/dev/null | head -n1 | tr -d '[:space:]')"
  [[ -n "$br" && "$br" =~ ^[0-9]+$ && "$br" -ge 8000 ]]
}

corebrum_record_mic_device() {
  local home="${HOME:-}" file line mic=""
  if [[ -n "${COREBRUM_RECORD_MIC:-}" ]]; then
    printf '%s\n' "$COREBRUM_RECORD_MIC"
    return 0
  fi
  [[ -z "$home" ]] && home="$(getent passwd "$(id -u)" | cut -d: -f6)"
  file="${home}/.local/state/corebrum/speech.conf"
  if [[ -f "$file" ]]; then
    while IFS= read -r line || [[ -n "$line" ]]; do
      case "$line" in
        mic=*)
          mic="${line#mic=}"
          break
          ;;
      esac
    done <"$file"
  fi
  if [[ -n "$mic" && "$mic" != default ]]; then
    printf '%s\n' "$mic"
    return 0
  fi
  if command -v pactl >/dev/null 2>&1; then
    mic="$(pactl get-default-source 2>/dev/null || true)"
    [[ -n "$mic" ]] && printf '%s\n' "$mic"
  fi
}

corebrum_record_wait_for_file() {
  local file="$1" i
  # Foreground wf-recorder in start has already exited; brief pause for the muxer trailer.
  sleep "${COREBRUM_RECORD_FINALIZE_DELAY:-1}"
  for ((i = 0; i < 30; i++)); do
    corebrum_record_file_playable "$file" && return 0
    sleep 0.15
  done
  return 1
}

corebrum_record_finalize_file() {
  local file="$1" want_audio="${2:-0}" tmp gain_db
  [[ -n "$file" && -f "$file" ]] || return 1
  [[ "${COREBRUM_RECORD_NO_FFPROBE:-0}" == 1 ]] && return 0
  command -v ffprobe >/dev/null 2>&1 || return 0
  if ! ffprobe -v error "$file" >/dev/null 2>&1; then
    return 1
  fi
  command -v ffmpeg >/dev/null 2>&1 || return 0
  tmp="$(mktemp "${file%/*}/.corebrum-record.XXXXXX.mp4")"
  gain_db="${COREBRUM_RECORD_AUDIO_GAIN_DB:-8}"
  if [[ "$want_audio" == 1 && "$gain_db" != 0 ]] \
    && corebrum_record_has_audio_stream "$file"; then
    if ffmpeg -nostdin -loglevel error -y -i "$file" -c:v copy \
      -af "volume=${gain_db}dB" -c:a aac -b:a 128k -movflags +faststart "$tmp" 2>/dev/null; then
      mv -f "$tmp" "$file"
      return 0
    fi
    rm -f "$tmp"
  fi
  tmp="$(mktemp "${file%/*}/.corebrum-record.XXXXXX.mp4")"
  if ffmpeg -nostdin -loglevel error -y -i "$file" -c copy -movflags +faststart "$tmp" 2>/dev/null; then
    mv -f "$tmp" "$file"
  else
    rm -f "$tmp"
  fi
  return 0
}

corebrum_record_place_preview_background() {
  local geom="$1"
  (
    if corebrum_record_place_preview "$geom"; then
      touch "$(corebrum_record_preview_ok_file)"
    elif kill -0 "$(cat "$(corebrum_record_runtime)/camera.pid" 2>/dev/null)" 2>/dev/null; then
      corebrum_record_parse_geom "$geom" || exit 0
      local px py
      px=$((COREBRUM_RECORD_X + COREBRUM_RECORD_W - COREBRUM_RECORD_PREVIEW_W - COREBRUM_RECORD_MARGIN))
      py=$((COREBRUM_RECORD_Y + COREBRUM_RECORD_H - COREBRUM_RECORD_PREVIEW_H - COREBRUM_RECORD_MARGIN))
      if corebrum_record_sway_camera_present; then
        corebrum_record_sway_place_camera "$px" "$py" '[app_id="org.corebrum.camera"]' \
          || corebrum_record_sway_place_camera "$px" "$py" '[title="Camera"]' \
          || true
      fi
      touch "$(corebrum_record_preview_ok_file)"
    fi
  ) >/dev/null 2>&1 &
}

corebrum_record_wf_recorder() {
  local geom="$1" file="$2" audio="$3" pid rc stopf
  local -a cmd=(wf-recorder -g "$geom" -f "$file" -c libx264 -x yuv420p)
  if [[ "$audio" == 1 ]]; then
    local mic=""
    mic="$(corebrum_record_mic_device || true)"
    if [[ -n "$mic" ]]; then
      cmd=(wf-recorder -a "$mic" --audio-backend=pulse -g "$geom" -f "$file" -c libx264 -x yuv420p)
      corebrum_record_log "audio device=${mic} backend=pulse"
    else
      cmd=(wf-recorder -a --audio-backend=pulse -g "$geom" -f "$file" -c libx264 -x yuv420p)
      corebrum_record_log "audio device=default backend=pulse"
    fi
  fi
  stopf="$(corebrum_record_stop_request_file)"
  "${cmd[@]}" &
  pid=$!
  printf '%s\n' "$pid" >"$(corebrum_record_wf_pid_file)"
  touch "$(corebrum_record_capturing_file)"
  corebrum_record_log "wf-recorder pid=${pid}"
  set +e
  while kill -0 "$pid" 2>/dev/null; do
    if [[ -f "$stopf" ]]; then
      rm -f "$stopf"
      kill -INT "$pid" 2>/dev/null || true
    fi
    sleep 0.15
  done
  wait "$pid" 2>/dev/null || true
  rc=$?
  rm -f "$(corebrum_record_wf_pid_file)" "$(corebrum_record_capturing_file)"
  corebrum_record_log "wf-recorder exit rc=${rc}"
  return "$rc"
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
    swaymsg '[app_id="org.corebrum.camera"] kill' >/dev/null 2>&1 || true
    swaymsg '[app_id="corebrum-camera"] kill' >/dev/null 2>&1 || true
    swaymsg '[title="Camera"] kill' >/dev/null 2>&1 || true
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

corebrum_record_sway_camera_match() {
  swaymsg -t get_tree 2>/dev/null | python3 -c 'import json,os,sys

def match(node):
    if (node.get("type") or "") != "con":
        for key in ("nodes", "floating_nodes"):
            for child in node.get(key) or []:
                hit = match(child)
                if hit:
                    return hit
        return None
    app_id = node.get("app_id") or ""
    name = node.get("name") or ""
    if app_id not in ("org.corebrum.camera", "corebrum-camera") and name != "Camera":
        for key in ("nodes", "floating_nodes"):
            for child in node.get(key) or []:
                hit = match(child)
                if hit:
                    return hit
        return None
    want_px = os.environ.get("COREBRUM_RECORD_PLACE_PX", "")
    if want_px:
        tol = int(os.environ.get("COREBRUM_RECORD_PLACE_TOL", "48"))
        want_py = int(os.environ["COREBRUM_RECORD_PLACE_PY"])
        want_px = int(want_px)
        want_w = int(os.environ.get("COREBRUM_RECORD_PLACE_W", "320"))
        want_h = int(os.environ.get("COREBRUM_RECORD_PLACE_H", "180"))
        rect = node.get("rect") or {}
        x = int(rect.get("x") or 0)
        y = int(rect.get("y") or 0)
        w = int(rect.get("width") or 0)
        h = int(rect.get("height") or 0)
        if (
            abs(x - want_px) > tol
            or abs(y - want_py) > tol
            or abs(w - want_w) > tol
            or abs(h - want_h) > tol
        ):
            return None
    return node

try:
    tree = json.load(sys.stdin)
except json.JSONDecodeError:
    sys.exit(1)
sys.exit(0 if match(tree) else 1)'
}

corebrum_record_sway_camera_present() {
  COREBRUM_RECORD_PLACE_PX= COREBRUM_RECORD_PLACE_PY= \
    COREBRUM_RECORD_PLACE_W= COREBRUM_RECORD_PLACE_H= \
    corebrum_record_sway_camera_match
}

corebrum_record_sway_camera_placed() {
  local px="$1" py="$2"
  COREBRUM_RECORD_PLACE_PX="$px" \
    COREBRUM_RECORD_PLACE_PY="$py" \
    COREBRUM_RECORD_PLACE_W="$COREBRUM_RECORD_PREVIEW_W" \
    COREBRUM_RECORD_PLACE_H="$COREBRUM_RECORD_PREVIEW_H" \
    corebrum_record_sway_camera_match
}

corebrum_record_sway_place_camera() {
  local px="$1" py="$2" crit="$3"
  swaymsg "${crit} floating enable, border none, sticky enable, move workspace current, move absolute position ${px} px ${py} px, resize set ${COREBRUM_RECORD_PREVIEW_W} px ${COREBRUM_RECORD_PREVIEW_H} px" >/dev/null 2>&1 || true
  sleep 0.05
  if corebrum_record_sway_camera_placed "$px" "$py"; then
    return 0
  fi
  if corebrum_record_sway_camera_present; then
    return 0
  fi
  return 1
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
  tries="${COREBRUM_RECORD_PLACE_TRIES:-20}"
  delay="${COREBRUM_RECORD_PLACE_DELAY:-0.06}"
  local pidfile pid
  pidfile="$(corebrum_record_runtime)/camera.pid"
  for ((i = 0; i < tries; i++)); do
    pid="$(cat "$pidfile" 2>/dev/null || true)"
    if [[ -n "$pid" ]] && ! kill -0 "$pid" 2>/dev/null; then
      return 1
    fi
    if corebrum_record_sway; then
      if corebrum_record_sway_place_camera "$px" "$py" '[app_id="org.corebrum.camera"]'; then
        return 0
      fi
      if corebrum_record_sway_place_camera "$px" "$py" '[app_id="corebrum-camera"]'; then
        return 0
      fi
      if corebrum_record_sway_place_camera "$px" "$py" '[title="Camera"]'; then
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
  local geom="$1" cmd pidfile err px py
  shift
  cmd="$(corebrum_record_preview_cmd)"
  pidfile="$(corebrum_record_runtime)/camera.pid"
  err="$(corebrum_record_runtime)/camera.err"
  corebrum_record_parse_geom "$geom" || return 1
  px=$((COREBRUM_RECORD_X + COREBRUM_RECORD_W - COREBRUM_RECORD_PREVIEW_W - COREBRUM_RECORD_MARGIN))
  py=$((COREBRUM_RECORD_Y + COREBRUM_RECORD_H - COREBRUM_RECORD_PREVIEW_H - COREBRUM_RECORD_MARGIN))
  : >"$err"
  GDK_APPLICATION_NAME=org.corebrum.camera \
    corebrum_record_spawn_preview "$cmd" "$@" >"$err" 2>&1 &
  printf '%s\n' "$!" >"$pidfile"
  sleep "${COREBRUM_RECORD_PREVIEW_GRACE:-0.2}"
  if ! kill -0 "$(cat "$pidfile" 2>/dev/null)" 2>/dev/null; then
    corebrum_record_sway_camera_present && corebrum_record_close_camera_window
    corebrum_record_stop_preview
    return 1
  fi
  corebrum_record_sway_place_camera "$px" "$py" '[app_id="org.corebrum.camera"]' \
    || corebrum_record_sway_place_camera "$px" "$py" '[title="Camera"]' \
    || true
  corebrum_record_place_preview_background "$geom"
  return 0
}

corebrum_record_output() {
  printf '%s\n' "${HOME}/Videos/corebrum-$(date +%Y%m%d-%H%M%S).mp4"
}

corebrum_record_run() {
  local geom="$1" want_audio="$2" want_video="$3" file
  file="$(corebrum_record_output)"
  mkdir -p "${HOME}/Videos"
  rm -f "$(corebrum_record_preview_ok_file)"
  corebrum_record_note_path "$file"
  corebrum_record_clear_stop_request
  corebrum_record_notify "Recording. Press $(corebrum_record_stop_keys) to stop."
  set +e
  corebrum_record_wf_recorder "$geom" "$file" "$want_audio"
  set -e
  if corebrum_record_wait_for_file "$file"; then
    corebrum_record_finalize_file "$file" "$want_audio" || true
    if [[ "$want_video" == 1 ]] && [[ ! -f "$(corebrum_record_preview_ok_file)" ]]; then
      corebrum_record_notify "The camera overlay is not in this recording."
    elif [[ "$want_audio" == 1 ]] && ! corebrum_record_has_usable_audio "$file"; then
      corebrum_record_notify "The microphone was not recorded. Check Setup → Voice → Microphone."
    fi
    if corebrum_record_file_playable "$file"; then
      corebrum_record_notify "Recording saved in Videos."
    fi
  else
    corebrum_record_notify "The recording was not finalized. Run: corebrum-record stop"
  fi
  rm -f "$(corebrum_record_path_file)" "$(corebrum_record_wf_pid_file)" \
    "$(corebrum_record_preview_ok_file)" "$(corebrum_record_capturing_file)"
  corebrum_record_clear_stop_request
}

corebrum_record_start() {
  local choice="" geom="" audio=0 video=""
  if corebrum_record_capture_active; then
    corebrum_record_request_stop 1
    corebrum_record_notify "Stopping the recording. Wait for Recording saved in Videos."
    return 0
  fi
  if corebrum_record_setup_active; then
    corebrum_record_notify "Recording is still starting."
    return 0
  fi
  corebrum_record_stop_recorder
  corebrum_record_stop_preview
  corebrum_record_clear_stop_request
  corebrum_record_discover
  choice="$(corebrum_record_choose)" || return 0
  [[ -n "$choice" ]] || return 0
  printf '%s\n' "$$" >"$(corebrum_record_start_pid_file)"
  corebrum_record_log "session pid=$$"
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
  geom="$(slurp)" || { corebrum_record_start_session_end; return 0; }
  [[ -n "$geom" ]] || { corebrum_record_start_session_end; return 0; }
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
  trap 'corebrum_record_on_stop_signal' USR1
  trap 'corebrum_record_stop_recorder; corebrum_record_stop_preview; corebrum_record_start_session_end' EXIT
  corebrum_record_log "record start pid=$$ choice=${choice} audio=${audio} video=${video:-none}"
  corebrum_record_run "$geom" "$audio" "${video:+1}"
}

corebrum_record_stop() {
  corebrum_record_request_stop 1
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
