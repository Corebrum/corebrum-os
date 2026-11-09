#!/usr/bin/env bash
# Autodim is a Super+Space Setup timer, independent of Autolock.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
menu="${ROOT}/scripts/desktop/corebrum-autodim.sh"
swayidle="${ROOT}/scripts/desktop/corebrum-swayidle.sh"
conf="${ROOT}/config/sway/config"
fail=0

if ! grep -q '/usr/local/bin/corebrum-autodim refresh' "${ROOT}/scripts/desktop/corebrum-launcher.sh"; then
  echo "FAIL: Super+Space does not refresh Autodim" >&2
  fail=1
fi
if ! grep -q 'corebrum-autodim' "${ROOT}/config/menu/corebrum-menu.json"; then
  echo "FAIL: Setup does not list Autodim" >&2
  fail=1
fi
if ! grep -q 'corebrum-swayidle start' "${ROOT}/scripts/desktop/corebrum-autolock.sh"; then
  echo "FAIL: Autolock does not delegate to corebrum-swayidle" >&2
  fail=1
fi
if ! grep -q 'corebrum-display-dim' "$swayidle"; then
  echo "FAIL: swayidle does not dim the display" >&2
  fail=1
fi
if ! grep -qE 'timeout "\$dim_sec" "\$dim_off" resume "\$dim_on"' "$swayidle"; then
  echo "FAIL: swayidle does not resume the display on the dim timeout" >&2
  fail=1
fi
if grep -qE '^\s*args\+\=\(resume "\$dim_on"\)' "$swayidle"; then
  echo "FAIL: swayidle resume must not be a lone swayidle event" >&2
  fail=1
fi
if ! grep -q 'Icon=display-brightness' "$menu"; then
  echo "FAIL: Autodim does not use a Papirus display icon" >&2
  fail=1
fi
if ! grep -q '/usr/local/bin/corebrum-autolock start' "$conf"; then
  echo "FAIL: the session does not start the idle timer" >&2
  fail=1
fi

runtime="$(mktemp -d)"
state="$(mktemp -d)"
export XDG_RUNTIME_DIR="$runtime"
export XDG_STATE_HOME="$state"
export HOME=/home/corebrum
export COREBRUM_AUTODIM_STUB=1

name="$(COREBRUM_AUTODIM_READY=0 bash "$menu" entry-name)"
if [[ "$name" != "Autodim   install" ]]; then
  echo "FAIL: missing swayidle is not marked install (got ${name})" >&2
  fail=1
fi
name="$(COREBRUM_AUTODIM_READY=1 bash "$menu" entry-name)"
if [[ "$name" != "Autodim" ]]; then
  echo "FAIL: installed swayidle still shows install (got ${name})" >&2
  fail=1
fi

output="$(COREBRUM_AUTODIM_READY=1 bash "$menu" open)"
if [[ "$output" != $'Off   on\n5 minutes\n10 minutes\n30 minutes\n1 hour' ]]; then
  echo "FAIL: Autodim list was ${output}" >&2
  fail=1
fi

output="$(COREBRUM_AUTODIM_READY=1 COREBRUM_AUTODIM_CHOICE='10 minutes' bash "$menu" open)"
if [[ "$output" != "minutes 10" ]]; then
  echo "FAIL: ten minute choice was ${output}" >&2
  fail=1
fi
if [[ "$(tr -d '[:space:]' <"${state}/corebrum/autodim-minutes")" != "10" ]]; then
  echo "FAIL: autodim minutes were not saved" >&2
  fail=1
fi

output="$(COREBRUM_AUTODIM_READY=1 COREBRUM_AUTODIM_MINUTES=10 bash "$menu" lines)"
if [[ "$output" != $'Off\n5 minutes\n10 minutes   on\n30 minutes\n1 hour' ]]; then
  echo "FAIL: the saved timer did not take the on mark (got ${output})" >&2
  fail=1
fi

output="$(COREBRUM_AUTODIM_READY=1 COREBRUM_AUTODIM_CHOICE='Off' bash "$menu" open)"
if [[ "$output" != "minutes 0" ]]; then
  echo "FAIL: off choice was ${output}" >&2
  fail=1
fi

output="$(COREBRUM_AUTODIM_READY=0 bash "$menu" open)"
if [[ "$output" != *'apt-get install -y swayidle'* ]]; then
  echo "FAIL: selecting Autodim did not install swayidle" >&2
  fail=1
fi

rm -rf "$runtime" "$state"
if [[ "$fail" -ne 0 ]]; then
  exit 1
fi
echo "autodim unit tests passed"
