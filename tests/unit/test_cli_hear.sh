#!/usr/bin/env bash
# Optional speech recognition uses a local recognizer and does not call the network.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CMD="${ROOT}/scripts/corebrum.sh"

help="$("$CMD" help)"
if ! grep -q 'voice list|test|set|hear' <<<"$help"; then
  echo "FAIL: help does not name voice hear" >&2
  exit 1
fi

state="$(mktemp -d)"
runtime="$(mktemp -d)"
stub="$(mktemp -d)"
recog="$(mktemp -d)"
model="$(mktemp -d)"
marker="$(mktemp)"
record="$(mktemp)"
net="$(mktemp)"
install="$(mktemp)"
tools="$(mktemp -d)"
trap 'rm -rf "$state" "$runtime" "$stub" "$recog" "$model" "$tools" "$marker" "$record" "$net" "$install"' EXIT
mkdir -p "${model}/en-us"

cat >"${stub}/espeak-ng" <<EOF
#!/bin/sh
printf '%s\n' "\$*" >>"${marker}"
exit 0
EOF
cat >"${stub}/pw-record" <<EOF
#!/bin/sh
printf '%s\n' "\$*" >>"${record}"
wav=""
for arg in "\$@"; do
  wav="\$arg"
done
dd if=/dev/zero bs=100 count=1 of="\$wav" status=none
printf '%s\n' "\$wav"
exit 1
EOF
cat >"${recog}/pocketsphinx" <<'EOF'
#!/bin/sh
printf '%s\n' '{"b":0,"d":1,"p":0.9,"t":"hello from the microphone","w":[]}'
exit 0
EOF
cat >"${recog}/pocketsphinx_continuous" <<'EOF'
#!/bin/sh
printf '%s\n' '<s> hello noble </s>'
exit 0
EOF
cat >"${stub}/curl" <<EOF
#!/bin/sh
printf '%s\n' curl >>"${net}"
exit 99
EOF
cat >"${stub}/sudo" <<EOF
#!/bin/sh
printf '%s\n' "\$*" >>"${install}"
exit 0
EOF
cat >"${stub}/apt-cache" <<'EOF'
#!/bin/sh
printf '%s\n' 'Candidate: 5.0.4-3ubuntu1'
exit 0
EOF
cat >"${stub}/apt-get" <<EOF
#!/bin/sh
printf '%s\n' "\$*" >>"${install}"
exit 0
EOF
chmod 755 "${stub}/espeak-ng" "${stub}/pw-record" "${recog}/pocketsphinx" \
  "${recog}/pocketsphinx_continuous" "${stub}/curl" "${stub}/sudo" \
  "${stub}/apt-cache" "${stub}/apt-get"

export XDG_STATE_HOME="$state"
export XDG_RUNTIME_DIR="$runtime"
export COREBRUM_SPEECH_BIN="${stub}/espeak-ng"
for tool in bash python3 awk grep rm mkdir mv mktemp id wc dd chmod cp cat date basename dirname readlink flock setsid sleep; do
  target="$(command -v "$tool" || true)"
  if [[ -n "$target" ]]; then
    ln -s "$target" "${tools}/${tool}"
  fi
done
export PATH="${stub}:${tools}"

if "$CMD" voice hear >/dev/null 2>"${state}/missing.err"; then
  echo "FAIL: voice hear succeeded without a recognizer" >&2
  exit 1
fi
if ! grep -q 'corebrum speak still works' "${state}/missing.err"; then
  echo "FAIL: a missing recognizer did not leave speak available" >&2
  exit 1
fi
if [[ -s "$install" || -s "$net" ]]; then
  echo "FAIL: voice hear installed packages or called curl" >&2
  exit 1
fi
if ! "$CMD" speak "still speaking" >/dev/null; then
  echo "FAIL: speak failed while recognition was absent" >&2
  exit 1
fi
if ! grep -q 'still speaking' "$marker"; then
  echo "FAIL: speak did not run while recognition was absent" >&2
  exit 1
fi

export COREBRUM_STT_BIN="${recog}/pocketsphinx"
export COREBRUM_RECORD_BIN="${stub}/pw-record"
heard="$("$CMD" voice hear 2)"
if [[ "$heard" != "hello from the microphone" ]]; then
  echo "FAIL: voice hear printed ${heard}" >&2
  exit 1
fi
if ! grep -q -- '-n 32000' "$record"; then
  echo "FAIL: voice hear did not record 2 seconds at 16 kHz" >&2
  exit 1
fi
if [[ -s "$net" ]]; then
  echo "FAIL: voice hear called curl" >&2
  exit 1
fi

"$CMD" voice disable >/dev/null
disabled="$("$CMD" voice hear 1)"
if [[ "$disabled" != "hello from the microphone" ]]; then
  echo "FAIL: disabling speech stopped recognition" >&2
  exit 1
fi

export COREBRUM_STT_BIN="${recog}/pocketsphinx_continuous"
noble="$("$CMD" voice hear 1)"
if [[ "$noble" != "hello noble" ]]; then
  echo "FAIL: noble recognition printed ${noble}" >&2
  exit 1
fi

unset COREBRUM_STT_BIN
export COREBRUM_STT_MODEL_DIR="$model"
if "$CMD" voice hear --install >/dev/null 2>"${state}/install.err"; then
  echo "FAIL: voice hear --install succeeded before the recognizer existed" >&2
  exit 1
fi
if ! grep -q 'pocketsphinx pocketsphinx-en-us' "$install"; then
  echo "FAIL: voice hear --install did not ask for the Ubuntu packages" >&2
  exit 1
fi
if [[ -s "$net" ]]; then
  echo "FAIL: voice hear --install called curl" >&2
  exit 1
fi

cat >"${stub}/sudo" <<EOF
#!/bin/sh
printf '%s\n' "\$*" >>"${install}"
cp "${recog}/pocketsphinx" "${stub}/pocketsphinx"
chmod 755 "${stub}/pocketsphinx"
exit 0
EOF
chmod 755 "${stub}/sudo"
installed="$("$CMD" voice hear --install 1)"
if [[ "$installed" != "hello from the microphone" ]]; then
  echo "FAIL: voice hear --install printed ${installed}" >&2
  exit 1
fi

if "$CMD" voice hear 0 >/dev/null 2>"${state}/zero.err"; then
  echo "FAIL: a zero-second recording was accepted" >&2
  exit 1
fi
if ! grep -q 'between 1 and 30 seconds' "${state}/zero.err"; then
  echo "FAIL: a zero-second recording was not rejected" >&2
  exit 1
fi

rm -f "${stub}/pocketsphinx"
unset COREBRUM_STT_MODEL_DIR
none="$(mktemp -d)"
cat >"${none}/apt-cache" <<'EOF'
#!/bin/sh
printf '%s\n' 'Candidate: (none)'
exit 0
EOF
chmod 755 "${none}/apt-cache"
if PATH="${none}:${PATH}" "$CMD" voice hear --install >/dev/null 2>"${state}/none.err"; then
  echo "FAIL: voice hear --install succeeded when pocketsphinx is absent from the archive" >&2
  exit 1
fi
if ! grep -q 'not in the Ubuntu archive' "${state}/none.err"; then
  echo "FAIL: a missing archive package was not reported" >&2
  exit 1
fi

export COREBRUM_HEAR_STUB=1
missing_toggle="$("$CMD" voice hear toggle)"
if ! grep -q 'Transcription was not installed.' <<<"$missing_toggle"; then
  echo "FAIL: toggle did not decline a missing recognizer: ${missing_toggle}" >&2
  exit 1
fi
if grep -q 'pocketsphinx pocketsphinx-en-us' <<<"$missing_toggle"; then
  echo "FAIL: declining the prompt installed transcription" >&2
  exit 1
fi
export COREBRUM_HEAR_INSTALL_ANSWER=Yes
yes_toggle="$("$CMD" voice hear toggle)"
if ! grep -q 'pocketsphinx pocketsphinx-en-us' <<<"$yes_toggle"; then
  echo "FAIL: Yes did not install Ubuntu pocketsphinx: ${yes_toggle}" >&2
  exit 1
fi
if ! grep -q 'Press Control+Space to listen.' <<<"$yes_toggle"; then
  echo "FAIL: Yes did not say how to listen after install" >&2
  exit 1
fi
unset COREBRUM_HEAR_INSTALL_ANSWER

cat >"${recog}/listen" <<'EOF'
#!/usr/bin/env python3
import signal
import sys
import time

signal.signal(signal.SIGINT, lambda *_: sys.exit(0))
path = sys.argv[-1]
with open(path, "wb") as handle:
    handle.write(b"x" * 100)
time.sleep(30)
EOF
chmod 755 "${recog}/listen"
export COREBRUM_STT_BIN="${recog}/pocketsphinx"
export COREBRUM_RECORD_BIN="${recog}/listen"
export COREBRUM_HEAR_LOG="${state}/hear.log"
: >"${state}/hear.log"
started="$("$CMD" voice hear toggle)"
if ! grep -q 'Listening. Press Control+Space to finish.' <<<"$started"; then
  echo "FAIL: toggle did not start listening: ${started}" >&2
  exit 1
fi
"$CMD" voice hear toggle >/dev/null
heard=""
for _ in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do
  if grep -q 'hello from the microphone' "${state}/hear.log"; then
    heard="$(cat "${state}/hear.log")"
    break
  fi
  sleep 0.1
done
if ! grep -q 'hello from the microphone' <<<"$heard"; then
  echo "FAIL: toggle did not transcribe: ${heard}" >&2
  exit 1
fi
if ! grep -q 'copy hello from the microphone' <<<"$heard"; then
  echo "FAIL: toggle did not copy the words: ${heard}" >&2
  exit 1
fi
unset COREBRUM_HEAR_STUB COREBRUM_HEAR_LOG

if ! grep -q 'doctor: speech recognition is not installed' "${ROOT}/scripts/lib/cli.sh"; then
  echo "FAIL: doctor does not report a missing recognizer" >&2
  exit 1
fi
if awk '
  /doctor: speech recognition is not installed/ { show=1 }
  show && /failed=1/ { found=1 }
  show && /duplicates=/ { exit found ? 0 : 1 }
' "${ROOT}/scripts/lib/cli.sh"; then
  echo "FAIL: a missing recognizer fails doctor" >&2
  exit 1
fi

echo "ok"
