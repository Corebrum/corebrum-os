#!/usr/bin/env bash
# Auto dim must not hide gtklock; lock must wake the panel first.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
dim="${ROOT}/scripts/desktop/corebrum-display-dim.sh"
lock="${ROOT}/scripts/desktop/corebrum-lock.sh"
fail=0

if ! grep -q 'corebrum-display-dim' "$lock"; then
  echo "FAIL: corebrum-lock does not wake the display" >&2
  fail=1
fi

state="$(mktemp -d)"
export XDG_STATE_HOME="$state"
export HOME=/home/corebrum
export COREBRUM_DISPLAY_DIM_STUB=1

output="$(COREBRUM_DISPLAY_DIM_LOCKED=1 bash "$dim" off)"
if [[ "$output" != "" && "$output" != "dim off" ]]; then
  echo "FAIL: locked off output was ${output}" >&2
  fail=1
fi
if [[ -f "${state}/corebrum/display-dimmed" ]]; then
  echo "FAIL: locked session should not create a dim mark" >&2
  fail=1
fi

output="$(COREBRUM_DISPLAY_DIM_LOCKED=0 bash "$dim" off)"
if [[ "$output" != "dim off" ]]; then
  echo "FAIL: unlocked off output was ${output}" >&2
  fail=1
fi

rm -rf "$state"
if [[ "$fail" -ne 0 ]]; then
  exit 1
fi
echo "display_dim unit tests passed"
