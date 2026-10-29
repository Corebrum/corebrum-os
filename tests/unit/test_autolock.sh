#!/usr/bin/env bash
# Autolock is a Super+Space timer. Stay awake pauses it for this session.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
menu="${ROOT}/scripts/desktop/corebrum-autolock.sh"
conf="${ROOT}/config/sway/config"
fail=0

if ! grep -q '/usr/local/bin/corebrum-autolock refresh' "${ROOT}/scripts/desktop/corebrum-launcher.sh"; then
  echo "FAIL: Super+Space does not refresh Autolock" >&2
  fail=1
fi
if ! grep -q 'bindsym $mod+Shift+Escape exec /usr/local/bin/corebrum-autolock toggle' "$conf"; then
  echo "FAIL: Super+Shift+Escape does not toggle stay awake" >&2
  fail=1
fi
if ! grep -q '/usr/local/bin/corebrum-autolock start' "$conf"; then
  echo "FAIL: the session does not start the autolock timer" >&2
  fail=1
fi
if ! grep -q 'swayidle honors a systemd idle inhibitor' "${ROOT}/config/sway/idle.conf"; then
  echo "FAIL: stay awake cannot pause swayidle" >&2
  fail=1
fi
if ! grep -q 'timeout=600' "${ROOT}/config/sway/idle.conf"; then
  echo "FAIL: the default autolock timer is not 10 minutes" >&2
  fail=1
fi
if ! grep -q '/etc/corebrum/sway/idle.conf' "${ROOT}/scripts/lib/desktop.sh"; then
  echo "FAIL: swayidle cannot see a system config" >&2
  fail=1
fi
if ! grep -q 'swayidle' "${ROOT}/scripts/phases/02-desktop.sh"; then
  echo "FAIL: the desktop profile does not consider swayidle" >&2
  fail=1
fi
if ! grep -q 'ExecStart=/bin/true' "${ROOT}/config/systemd/user/hypridle.service.d/corebrum.conf"; then
  echo "FAIL: the packaged hypridle service can start without the Corebrum config" >&2
  fail=1
fi

runtime="$(mktemp -d)"
state="$(mktemp -d)"
export XDG_RUNTIME_DIR="$runtime"
export XDG_STATE_HOME="$state"
export HOME=/home/corebrum
export COREBRUM_AUTOLOCK_STUB=1

name="$(COREBRUM_AUTOLOCK_READY=0 bash "$menu" entry-name)"
if [[ "$name" != "Autolock   install" ]]; then
  echo "FAIL: missing hypridle is not marked install (got ${name})" >&2
  fail=1
fi
name="$(COREBRUM_AUTOLOCK_READY=1 bash "$menu" entry-name)"
if [[ "$name" != "Autolock" ]]; then
  echo "FAIL: installed hypridle still shows install (got ${name})" >&2
  fail=1
fi

output="$(COREBRUM_AUTOLOCK_READY=1 COREBRUM_AUTOLOCK_AWAKE=0 bash "$menu" open)"
if [[ "$output" != $'Stay awake\n5 minutes\n10 minutes   on\n30 minutes\n1 hour' ]]; then
  echo "FAIL: autolock list was ${output}" >&2
  fail=1
fi
output="$(COREBRUM_AUTOLOCK_READY=1 COREBRUM_AUTOLOCK_AWAKE=1 COREBRUM_AUTOLOCK_MINUTES=30 bash "$menu" open)"
if [[ "$output" != $'Stay awake   on\n5 minutes\n10 minutes\n30 minutes   on\n1 hour' ]]; then
  echo "FAIL: awake list was ${output}" >&2
  fail=1
fi

output="$(COREBRUM_AUTOLOCK_READY=1 COREBRUM_AUTOLOCK_CHOICE='1 hour' bash "$menu" open)"
if [[ "$output" != "minutes 60" ]]; then
  echo "FAIL: hour choice was ${output}" >&2
  fail=1
fi
if ! grep -q 'timeout=3600' "${state}/corebrum/idle.conf"; then
  echo "FAIL: saved idle config is not one hour" >&2
  fail=1
fi
output="$(COREBRUM_AUTOLOCK_READY=1 COREBRUM_AUTOLOCK_AWAKE=1 bash "$menu" lines)"
if [[ "$output" != $'Stay awake   on\n5 minutes\n10 minutes\n30 minutes\n1 hour   on' ]]; then
  echo "FAIL: the saved timer did not take the on mark (got ${output})" >&2
  fail=1
fi
set_minutes="$(awk '
  /^corebrum_autolock_set_minutes\(\)/ { capture = 1 }
  capture { body = body $0 "\n" }
  capture && /^}/ { exit }
  END { printf "%s", body }
' "$menu")"
if [[ "$set_minutes" == *stay_awake_stop* ]]; then
  echo "FAIL: choosing a timer turns Stay awake off" >&2
  fail=1
fi
if ! awk '
  /^corebrum_autolock_open\(\)/ { capture = 1 }
  capture { body = body $0 "\n" }
  capture && /^}/ { exit }
  END { exit index(body, "while true") ? 0 : 1 }
' "$menu"; then
  echo "FAIL: the autolock list does not redraw the on mark" >&2
  fail=1
fi
output="$(COREBRUM_AUTOLOCK_AWAKE=0 bash "$menu" toggle)"
if [[ "$output" != "awake on" ]]; then
  echo "FAIL: stay awake did not turn on (got ${output})" >&2
  fail=1
fi
output="$(COREBRUM_AUTOLOCK_AWAKE=1 bash "$menu" toggle)"
if [[ "$output" != "awake off" ]]; then
  echo "FAIL: stay awake did not turn off (got ${output})" >&2
  fail=1
fi

output="$(COREBRUM_AUTOLOCK_READY=0 bash "$menu" open)"
if [[ "$output" != *'apt-get install -y swayidle'* ]]; then
  echo "FAIL: selecting Autolock did not install swayidle" >&2
  fail=1
fi
if [[ "$output" != *'apt-get install -y swayidle gtklock'* ]]; then
  echo "FAIL: Autolock on resolute did not install gtklock" >&2
  fail=1
fi
if [[ "$output" != *'sudo corebrum install desktop'* ]]; then
  echo "FAIL: Autolock on noble did not point at the gtklock 4 build" >&2
  fail=1
fi
if [[ "$output" != *'swayidle is not in this Ubuntu archive.'* ]]; then
  echo "FAIL: the installer does not explain a missing archive package" >&2
  fail=1
fi

rm -rf "$runtime" "$state"
if [[ "$fail" -ne 0 ]]; then
  exit 1
fi
echo "autolock unit tests passed"
