#!/usr/bin/env bash
# Screen recording lists a microphone, a webcam, and RealSense only when each is present.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
record="${ROOT}/scripts/desktop/corebrum-record.sh"
tmp="$(mktemp -d)"
bin="${tmp}/bin"
log="${tmp}/log"
runtime="${tmp}/runtime"
home="${tmp}/home"
mkdir -p "$bin" "$runtime" "$home"
: >"$log"

cat >"${bin}/slurp" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "${COREBRUM_TEST_GEOM:-10,20 800x600}"
EOF
cat >"${bin}/wf-recorder" <<'EOF'
#!/usr/bin/env bash
printf 'wf-recorder %s\n' "$*" >>"$COREBRUM_TEST_LOG"
file=""
prev=""
for arg in "$@"; do
  if [[ "$prev" == "-f" ]]; then
    file="$arg"
  fi
  prev="$arg"
done
if [[ -n "$file" ]]; then
  mkdir -p "$(dirname "$file")"
  : >"$file"
fi
if [[ "${COREBRUM_TEST_AUDIO_FAIL:-0}" == 1 && " $* " == *" -a "* ]]; then
  rm -f "$file"
  exit 1
fi
if [[ -n "$file" ]]; then
  printf 'x' >"$file"
fi
EOF
cat >"${bin}/fuzzel" <<'EOF'
#!/usr/bin/env bash
printf 'fuzzel\n' >>"$COREBRUM_TEST_LOG"
printf '%s\n' '--- menu ---' >>"$COREBRUM_TEST_LOG"
cat >>"$COREBRUM_TEST_LOG"
printf '%s\n' '--- end ---' >>"$COREBRUM_TEST_LOG"
if [[ "${COREBRUM_TEST_FUZZEL_STATUS:-0}" -ne 0 ]]; then
  exit "$COREBRUM_TEST_FUZZEL_STATUS"
fi
printf '%s\n' "${COREBRUM_TEST_FUZZEL_CHOICE:-Screen}"
EOF
cat >"${bin}/notify-send" <<'EOF'
#!/usr/bin/env bash
printf 'notify %s\n' "$*" >>"$COREBRUM_TEST_LOG"
EOF
cat >"${bin}/swaymsg" <<'EOF'
#!/usr/bin/env bash
printf 'swaymsg %s\n' "$*" >>"$COREBRUM_TEST_LOG"
if [[ "$1" == "-t" && "$2" == "get_tree" ]]; then
  if [[ "${COREBRUM_TEST_CAMERA_WINDOW:-1}" == 1 ]]; then
    cat <<'JSON'
{"type":"root","nodes":[{"type":"output","nodes":[{"type":"workspace","nodes":[],"floating_nodes":[{"type":"con","name":"Camera","app_id":"org.corebrum.camera","sticky":true,"floating":"user_on","rect":{"x":474,"y":424,"width":320,"height":180}}]}]}]}
JSON
  else
    printf '%s\n' '{"type":"root","nodes":[]}'
  fi
  exit 0
fi
if [[ "${COREBRUM_TEST_CAMERA_WINDOW:-1}" != 1 ]]; then
  exit 2
fi
EOF
cat >"${bin}/hyprctl" <<'EOF'
#!/usr/bin/env bash
printf 'hyprctl %s\n' "$*" >>"$COREBRUM_TEST_LOG"
if [[ "$1" == "clients" ]]; then
  if [[ "${COREBRUM_TEST_CAMERA_WINDOW:-1}" == 1 ]]; then
    printf '%s\n' '[{"address":"0xabc","class":"corebrum-camera","title":"Camera"}]'
  else
    printf '%s\n' '[]'
  fi
fi
EOF
cat >"${bin}/pkill" <<'EOF'
#!/usr/bin/env bash
printf 'pkill %s\n' "$*" >>"$COREBRUM_TEST_LOG"
EOF
cat >"${bin}/preview" <<'EOF'
#!/usr/bin/env bash
{
  printf 'preview'
  if [[ "$#" -gt 0 ]]; then
    printf ' %s' "$*"
  fi
  printf '\n'
} >>"$COREBRUM_TEST_LOG"
if [[ "${COREBRUM_TEST_PREVIEW_FAIL:-0}" == 1 ]]; then
  exit 1
fi
exec sleep 30
EOF
chmod +x "${bin}/slurp" "${bin}/wf-recorder" "${bin}/fuzzel" "${bin}/notify-send" \
  "${bin}/swaymsg" "${bin}/hyprctl" "${bin}/pkill" "${bin}/preview"

run_record() {
  env \
    PATH="${bin}:${PATH}" \
    HOME="$home" \
    XDG_RUNTIME_DIR="$runtime" \
    COREBRUM_TEST_LOG="$log" \
    COREBRUM_CAMERA_PREVIEW="${COREBRUM_CAMERA_PREVIEW:-${bin}/preview}" \
    COREBRUM_RECORD_SDK="${COREBRUM_RECORD_SDK:-0}" \
    COREBRUM_RECORD_HAS_AUDIO="${COREBRUM_RECORD_HAS_AUDIO:-0}" \
    COREBRUM_RECORD_WEBCAM="${COREBRUM_RECORD_WEBCAM-}" \
    COREBRUM_RECORD_PLACE_DELAY=0 \
    COREBRUM_RECORD_PLACE_TRIES=2 \
    COREBRUM_RECORD_NO_FFPROBE=1 \
    COREBRUM_RECORD_FINALIZE_DELAY=0 \
    "$@" \
    bash "$record" start
}

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  printf '%s\n' "$(cat "$log")" >&2
  exit 1
}

: >"$log"
run_record
if grep -q '^fuzzel$' "$log"; then
  fail "no devices asked which recording to make"
fi
if ! grep -qE '^wf-recorder .*-g 10,20 800x600 -f .*/Videos/corebrum-' "$log"; then
  fail "no devices did not record the screen"
fi
if ! grep -q ' -c libx264 ' "$log"; then
  fail "wf-recorder did not use libx264"
fi
if grep -q '^preview' "$log"; then
  fail "no devices opened a camera"
fi

: >"$log"
mkdir -p "${home}/.local/state/corebrum"
printf '%s\n' 'mic=test.pipewire.source' >"${home}/.local/state/corebrum/speech.conf"
COREBRUM_RECORD_HAS_AUDIO=1 COREBRUM_RECORD_CHOICE="Screen and audio" run_record
if ! grep -qE '^wf-recorder -a test\.pipewire\.source --audio-backend=pulse ' "$log"; then
  fail "audio did not pass the speech.conf microphone to wf-recorder"
fi
if grep -q '^preview' "$log"; then
  fail "audio opened a camera"
fi

: >"$log"
COREBRUM_TEST_AUDIO_FAIL=1 COREBRUM_RECORD_HAS_AUDIO=1 COREBRUM_RECORD_CHOICE="Screen and audio" run_record
if ! grep -q 'not finalized' "$log"; then
  fail "a failed microphone recording was not reported"
fi
if [[ "$(grep -c '^wf-recorder ' "$log")" -ne 1 ]]; then
  fail "a failed microphone recording started more than one wf-recorder"
fi

cat >"${tmp}/preview.py" <<'EOF'
import os
import sys
with open(os.environ["COREBRUM_TEST_LOG"], "a", encoding="utf-8") as handle:
    handle.write("py-preview " + " ".join(sys.argv[1:]) + "\n")
raise SystemExit(1)
EOF
chmod 644 "${tmp}/preview.py"

: >"$log"
COREBRUM_CAMERA_PREVIEW="${tmp}/preview.py" COREBRUM_RECORD_WEBCAM=/dev/video6 \
  COREBRUM_RECORD_CHOICE="Screen and webcam" run_record
if ! grep -qx 'py-preview --v4l2 /dev/video6' "$log"; then
  fail "a non-executable preview was not started with python3"
fi
if ! grep -q 'camera overlay is not' "$log"; then
  fail "a preview that exited was not reported after save"
fi

cat >"${tmp}/stay.py" <<'EOF'
import os
import time
with open(os.environ["COREBRUM_TEST_PID"], "w", encoding="utf-8") as handle:
    handle.write(str(os.getpid()))
time.sleep(30)
EOF
chmod 644 "${tmp}/stay.py"
pidfile="${tmp}/preview.pid"
rm -f "$pidfile"
: >"$log"
COREBRUM_CAMERA_PREVIEW="${tmp}/stay.py" COREBRUM_TEST_PID="$pidfile" \
  COREBRUM_RECORD_WEBCAM=/dev/video6 COREBRUM_RECORD_CHOICE="Screen and webcam" run_record
if [[ ! -s "$pidfile" ]]; then
  fail "the webcam preview did not record its process id"
fi
preview_pid="$(cat "$pidfile")"
if kill -0 "$preview_pid" 2>/dev/null; then
  kill "$preview_pid" 2>/dev/null || true
  fail "stop left the webcam preview running"
fi

: >"$log"
COREBRUM_RECORD_WEBCAM=/dev/video6 COREBRUM_RECORD_CHOICE="Screen and webcam" run_record
if ! grep -qx 'preview --v4l2 /dev/video6' "$log"; then
  fail "the webcam preview was not opened from the V4L2 device"
fi
if grep -qx 'preview' "$log"; then
  fail "the webcam choice opened the RealSense preview"
fi

: >"$log"
COREBRUM_RECORD_SDK=1 COREBRUM_RECORD_CHOICE="Screen and RealSense" run_record
if ! grep -qx 'preview' "$log"; then
  fail "RealSense did not open its preview"
fi
if grep -q -- '--v4l2' "$log"; then
  fail "RealSense opened the webcam device"
fi
if ! grep -q 'swaymsg \[app_id="org.corebrum.camera"\] floating enable, border none, sticky enable, move workspace current, move absolute position 474 px 424 px, resize set 320 px 180 px' "$log"; then
  fail "the preview was not moved to the bottom-right"
fi
if ! grep -q 'swaymsg -t get_tree' "$log"; then
  fail "placement did not verify the sticky camera window"
fi

: >"$log"
COREBRUM_TEST_GEOM="0,0 100x80" COREBRUM_RECORD_SDK=1 COREBRUM_RECORD_CHOICE="Screen and RealSense" run_record
if grep -q '^preview' "$log"; then
  fail "a small selection opened the camera"
fi
if ! grep -q 'too small for the camera' "$log"; then
  fail "a small selection did not explain the fallback"
fi

: >"$log"
COREBRUM_TEST_PREVIEW_FAIL=1 COREBRUM_RECORD_SDK=1 COREBRUM_RECORD_CHOICE="Screen and RealSense" run_record
if ! grep -q 'camera overlay is not' "$log"; then
  fail "a camera that did not open was not reported after save"
fi
if ! grep -q '^wf-recorder ' "$log"; then
  fail "a busy camera did not fall back to the screen"
fi

: >"$log"
COREBRUM_RECORD_SDK=0 COREBRUM_RECORD_HAS_AUDIO=1 COREBRUM_RECORD_WEBCAM=/dev/video6 \
  COREBRUM_TEST_FUZZEL_STATUS=1 run_record
if grep -q 'RealSense' "$log"; then
  fail "the list offered RealSense without the SDK"
fi
if ! grep -qx 'Screen and audio' "$log" || ! grep -qx 'Screen and webcam' "$log" \
  || ! grep -qx 'Screen, webcam, and audio' "$log"; then
  fail "the list omitted the microphone or the webcam"
fi
if grep -q '^wf-recorder ' "$log"; then
  fail "cancelling the choice still recorded"
fi

: >"$log"
wf_sleep_pid=""
sleep 300 &
wf_sleep_pid=$!
mkdir -p "${home}/.local/state/corebrum"
printf '%s\n' "$wf_sleep_pid" >"${home}/.local/state/corebrum/wf-recorder.pid"
env PATH="${bin}:${PATH}" HOME="$home" XDG_RUNTIME_DIR="$runtime" COREBRUM_TEST_LOG="$log" \
  bash "$record" stop
if kill -0 "$wf_sleep_pid" 2>/dev/null; then
  kill "$wf_sleep_pid" 2>/dev/null || true
  fail "stop did not interrupt wf-recorder"
fi
if ! grep -q 'swaymsg \[app_id="org.corebrum.camera"\] kill' "$log"; then
  fail "stop did not close the camera window"
fi

sleep_pid=""
sleep 30 &
sleep_pid=$!
printf '%s\n' "$sleep_pid" >"${runtime}/corebrum/camera.pid"
env PATH="${bin}:${PATH}" HOME="$home" XDG_RUNTIME_DIR="$runtime" COREBRUM_TEST_LOG="$log" \
  bash "$record" stop
if kill -0 "$sleep_pid" 2>/dev/null; then
  kill "$sleep_pid" 2>/dev/null || true
  fail "stop left the camera preview running"
fi

rm -rf "$tmp"
echo "record unit tests passed"
