#!/usr/bin/env bash
# Autodim defers gtklock until wake; gtklock stays visible while locked.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
dim="${ROOT}/scripts/desktop/corebrum-display-dim.sh"
lock="${ROOT}/scripts/desktop/corebrum-lock.sh"
swayidle="${ROOT}/scripts/desktop/corebrum-swayidle.sh"
bindir="$(mktemp -d)"
fail=0

if ! grep -q 'corebrum_lock_wake_display' "$lock"; then
  echo "FAIL: manual lock does not wake the display" >&2
  fail=1
fi
if ! grep -q 'corebrum-lock idle' "$swayidle"; then
  echo "FAIL: swayidle does not use idle autolock" >&2
  fail=1
fi
if ! grep -q 'pending-autolock' "$dim"; then
  echo "FAIL: display-dim does not handle deferred autolock" >&2
  fail=1
fi

cat >"${bindir}/corebrum-lock" <<EOF
#!/usr/bin/env bash
export COREBRUM_LOCK_GTKLOCK_STUB=1
exec bash "${lock}" "\$@"
EOF
cat >"${bindir}/corebrum-display-dim" <<EOF
#!/usr/bin/env bash
exec bash "${dim}" "\$@"
EOF
chmod +x "${bindir}/corebrum-lock" "${bindir}/corebrum-display-dim"

state="$(mktemp -d)"
export XDG_RUNTIME_DIR="$(mktemp -d)"
export XDG_STATE_HOME="$state"
export HOME=/home/corebrum
export PATH="${bindir}:${PATH}"
export COREBRUM_DISPLAY_DIM_STUB=1
export COREBRUM_LOCK_IDLE_STUB=1
export COREBRUM_LOCK_GTKLOCK_STUB=1

output="$(COREBRUM_DISPLAY_DIM_LOCKED=1 bash "$dim" off)"
if [[ -f "${state}/corebrum/display-dimmed" ]]; then
  echo "FAIL: locked session should not create a dim mark" >&2
  fail=1
fi

output="$(COREBRUM_DISPLAY_DIM_LOCKED=0 bash "$dim" off)"
if [[ "$output" != "dim off" ]]; then
  echo "FAIL: unlocked off output was ${output}" >&2
  fail=1
fi

mkdir -p "${state}/corebrum"
touch "${state}/corebrum/display-dimmed"
output="$(bash "$lock" idle)"
if [[ "$output" != "idle defer" ]]; then
  echo "FAIL: idle lock while dimmed was ${output}" >&2
  fail=1
fi
if [[ ! -f "${state}/corebrum/pending-autolock" ]]; then
  echo "FAIL: idle lock did not defer gtklock" >&2
  fail=1
fi

rm -f "${state}/corebrum/display-dimmed"
output="$(COREBRUM_LOCK_IDLE_STUB=0 bash "$lock" idle)"
if [[ "$output" != "gtklock" ]]; then
  echo "FAIL: idle lock while lit was ${output}" >&2
  fail=1
fi

mkdir -p "${state}/corebrum"
touch "${state}/corebrum/display-dimmed"
touch "${state}/corebrum/pending-autolock"
output="$(bash "$dim" on)"
if [[ "$output" != $'dim on\ngtklock' ]]; then
  echo "FAIL: dim on with pending autolock was ${output}" >&2
  fail=1
fi
if [[ -f "${state}/corebrum/pending-autolock" ]]; then
  echo "FAIL: pending autolock should clear after dim on" >&2
  fail=1
fi

rm -rf "$state" "$bindir" "$XDG_RUNTIME_DIR"
if [[ "$fail" -ne 0 ]]; then
  exit 1
fi
echo "display_dim unit tests passed"
