#!/usr/bin/env bash
# Local speech uses espeak and does not call a cloud tool.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CMD="${ROOT}/scripts/corebrum.sh"

help="$("$CMD" help)"
for name in 'speak "text"' "speak listen" "voice list"; do
  if ! grep -q "$name" <<<"$help"; then
    echo "FAIL: help does not name ${name}" >&2
    exit 1
  fi
done

state="$(mktemp -d)"
runtime="$(mktemp -d)"
stub="$(mktemp -d)"
marker="$(mktemp)"
net="$(mktemp)"
setup="$(mktemp)"
trap 'rm -rf "$state" "$runtime" "$stub" "$marker" "$net" "$setup"' EXIT

cat >"${stub}/espeak-ng" <<EOF
#!/bin/sh
printf '%s\n' "\$*" >>"${marker}"
if [ "\${1:-}" = "--voices" ]; then
  printf '%s\n' "en English"
  exit 0
fi
if [ -n "\${SPEECH_SLEEP:-}" ]; then
  sleep "\$SPEECH_SLEEP"
fi
exit 0
EOF
cat >"${stub}/curl" <<EOF
#!/bin/sh
printf '%s\n' curl >>"${net}"
exit 99
EOF
cat >"${stub}/ros2" <<'EOF'
#!/bin/sh
if [ "${1:-}" = "topic" ] && [ "${2:-}" = "echo" ]; then
  printf '%s\n' "hello from ros"
  printf '%s\n' "---"
  exit 0
fi
exit 1
EOF
chmod 755 "${stub}/espeak-ng" "${stub}/curl" "${stub}/ros2"

export XDG_STATE_HOME="$state"
export XDG_RUNTIME_DIR="$runtime"
export COREBRUM_SPEECH_BIN="${stub}/espeak-ng"
export PATH="${stub}:${PATH}"

spoken="$("$CMD" speak "hello world")"
if [[ -n "$spoken" ]]; then
  echo "FAIL: speak printed unexpected output: ${spoken}" >&2
  exit 1
fi
if ! grep -q "hello world" "$marker"; then
  echo "FAIL: speak did not pass the text to espeak" >&2
  exit 1
fi
if [[ -s "$net" ]]; then
  echo "FAIL: speak called curl" >&2
  exit 1
fi

voices="$("$CMD" voice list)"
if ! grep -q "en English" <<<"$voices"; then
  echo "FAIL: voice list did not print espeak voices" >&2
  exit 1
fi

"$CMD" voice set espeak en >/dev/null
if ! grep -q '^voice=en$' "${state}/corebrum/speech.conf"; then
  echo "FAIL: voice set did not store the espeak voice" >&2
  exit 1
fi
if ! "$CMD" voice set elevenlabs >/dev/null 2>"${state}/eleven.err"; then
  if ! grep -q "Local speech uses espeak" "${state}/eleven.err"; then
    echo "FAIL: voice set elevenlabs did not stay on espeak" >&2
    exit 1
  fi
else
  echo "FAIL: voice set elevenlabs succeeded" >&2
  exit 1
fi
if [[ -s "$net" ]]; then
  echo "FAIL: voice set called curl" >&2
  exit 1
fi

before="$(wc -c <"$marker")"
disabled="$("$CMD" voice disable)"
if ! grep -q "speech: disabled" <<<"$disabled"; then
  echo "FAIL: voice disable did not report disabled" >&2
  exit 1
fi
quiet="$("$CMD" speak "should stay quiet")"
if ! grep -q "speech is disabled" <<<"$quiet"; then
  echo "FAIL: disabled speak did not say speech is disabled" >&2
  exit 1
fi
after="$(wc -c <"$marker")"
if [[ "$before" -ne "$after" ]]; then
  echo "FAIL: disabled speak called espeak" >&2
  exit 1
fi
"$CMD" voice enable >/dev/null

export SPEECH_SLEEP=30
"$CMD" speak "first" &
first=$!
sleep 0.2
SPEECH_SLEEP= "$CMD" speak "second"
wait "$first" || true
if ! grep -q "second" "$marker"; then
  echo "FAIL: a second speak did not run" >&2
  exit 1
fi
unset SPEECH_SLEEP

export COREBRUM_ROS_SETUP="$setup"
heard="$("$CMD" speak listen --once)"
if [[ -n "$heard" ]]; then
  echo "FAIL: speak listen printed unexpected output: ${heard}" >&2
  exit 1
fi
if ! grep -q "hello from ros" "$marker"; then
  echo "FAIL: speak listen did not speak the ROS string" >&2
  exit 1
fi
if grep -q -- "---" "$marker"; then
  echo "FAIL: speak listen passed the ROS echo separator to espeak" >&2
  exit 1
fi

export COREBRUM_ROS_SETUP="${state}/missing-setup"
if "$CMD" speak listen --once >/dev/null 2>"${state}/ros.err"; then
  echo "FAIL: speak listen succeeded without ROS" >&2
  exit 1
fi
if ! grep -q "ROS 2 is not installed" "${state}/ros.err"; then
  echo "FAIL: speak listen without ROS did not say ROS is missing" >&2
  exit 1
fi

if ! grep -q 'doctor: espeak is not installed' "${ROOT}/scripts/lib/cli.sh"; then
  echo "FAIL: doctor does not report a missing espeak install" >&2
  exit 1
fi
if awk '
  /doctor: espeak is not installed/ { show=1 }
  show && /failed=1/ { print; found=1 }
  show && /duplicates=/ { exit found ? 0 : 1 }
' "${ROOT}/scripts/lib/cli.sh"; then
  echo "FAIL: a missing espeak install fails doctor" >&2
  exit 1
fi

echo "ok"
