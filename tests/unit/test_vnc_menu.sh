#!/usr/bin/env bash
# Remote desktop is a Super+Space action and is not part of the desktop package list.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
menu="${ROOT}/scripts/desktop/corebrum-vnc-menu.sh"
fail=0

assert_grep() {
  local pattern="$1" file="$2" message="$3"
  if ! grep -qE -e "$pattern" "$file"; then
    echo "FAIL: ${message}" >&2
    fail=1
  fi
}

assert_grep 'corebrum-vnc-menu refresh' "${ROOT}/scripts/desktop/corebrum-launcher.sh" "launcher does not refresh Remote desktop"
assert_grep 'corebrum-vnc-menu.sh' "${ROOT}/scripts/lib/desktop.sh" "desktop install does not install the VNC menu"
assert_grep '/usr/local/bin/corebrum-vnc-menu' "${ROOT}/scripts/lib/desktop.sh" "desktop uninstall does not remove the VNC menu"
assert_grep 'apt-get install -y wayvnc' "$menu" "installer does not install Ubuntu wayvnc"
assert_grep 'wayvnc is not in this Ubuntu archive' "$menu" "installer does not explain a missing archive package"
assert_grep 'address=127.0.0.1' "$menu" "wayvnc is still reachable from the network"
assert_grep '0\.0\.0\.0:5900' "$menu" "the Mac listener is not on port 5900"
assert_grep 'XDG_CONFIG_HOME=' "$menu" "wayvnc can read a config under the user home"
assert_grep 'vnc://' "$menu" "instructions do not show a VNC address"
assert_grep 'Connect to Server' "$menu" "instructions do not tell a Mac how to connect"
assert_grep 'corebrum-vnc-proxy' "$menu" "Screen Sharing is still talking to wayvnc directly"
assert_grep 'does not ask for a name' "$menu" "instructions still tell the Mac to enter a name"
assert_grep 'Command key is Super' "$menu" "instructions do not say Command is Super"
assert_grep 'TigerVNC Viewer' "$menu" "instructions do not tell Windows how to connect"
assert_grep '::5900' "$menu" "Windows instructions use a single colon"
assert_grep 'Remmina' "$menu" "instructions do not tell Linux how to connect"
assert_grep 'Leave the username empty' "$menu" "Linux instructions ask for a username"
if grep -qE '^wayvnc$' "${ROOT}/manifests/packages/desktop.txt"; then
  echo "FAIL: desktop profile preinstalls wayvnc" >&2
  fail=1
fi

runtime="$(mktemp -d)"
export XDG_RUNTIME_DIR="$runtime"
export HOME=/home/corebrum
export COREBRUM_VNC_STUB=1
export COREBRUM_VNC_USER=corebrum
export COREBRUM_VNC_PASSWORD=testpass
export COREBRUM_VNC_ADDRESSES=$'192.168.8.190\n10.1.1.5'

name="$(COREBRUM_VNC_READY=0 bash "$menu" entry-name)"
if [[ "$name" != "Remote desktop   install" ]]; then
  echo "FAIL: missing wayvnc is not marked install (got ${name})" >&2
  fail=1
fi
name="$(COREBRUM_VNC_READY=1 COREBRUM_VNC_RUNNING=0 bash "$menu" entry-name)"
if [[ "$name" != "Remote desktop" ]]; then
  echo "FAIL: installed wayvnc still shows install or on (got ${name})" >&2
  fail=1
fi
name="$(COREBRUM_VNC_READY=1 COREBRUM_VNC_RUNNING=1 bash "$menu" entry-name)"
if [[ "$name" != "Remote desktop   on" ]]; then
  echo "FAIL: a running server is not marked on (got ${name})" >&2
  fail=1
fi

COREBRUM_VNC_READY=1 COREBRUM_VNC_RUNNING=0 bash "$menu" refresh
desktop="${runtime}/corebrum/applications/corebrum-vnc.desktop"
if ! grep -q '^Name=Remote desktop$' "$desktop"; then
  echo "FAIL: desktop entry name is not Remote desktop" >&2
  fail=1
fi
if ! grep -q '^Exec=/usr/local/bin/corebrum-vnc-menu open$' "$desktop"; then
  echo "FAIL: desktop entry does not open the remote desktop menu" >&2
  fail=1
fi

lines="$(COREBRUM_VNC_READY=1 COREBRUM_VNC_RUNNING=1 bash "$menu" open)"
if [[ "$lines" != $'Start   on\nStop\nHow to connect' ]]; then
  echo "FAIL: running menu lines were ${lines}" >&2
  fail=1
fi

started="$(COREBRUM_VNC_READY=1 COREBRUM_VNC_RUNNING=0 COREBRUM_VNC_CHOICE=Start bash "$menu" open)"
if ! grep -q 'wayvnc --render-cursor --config' <<<"$started"; then
  echo "FAIL: Start does not run wayvnc" >&2
  fail=1
fi
if ! grep -q 'corebrum-vnc-proxy --listen 0.0.0.0:5900' <<<"$started"; then
  echo "FAIL: Start does not run the Screen Sharing password proxy" >&2
  fail=1
fi
if ! grep -q 'vnc://192.168.8.190' <<<"$started"; then
  echo "FAIL: Start does not show the Mac address" >&2
  fail=1
fi
if ! grep -q 'vnc://10.1.1.5' <<<"$started"; then
  echo "FAIL: Start hides an extra network address" >&2
  fail=1
fi
if ! grep -q '192.168.8.190::5900' <<<"$started"; then
  echo "FAIL: Start does not show the TigerVNC address" >&2
  fail=1
fi
if ! grep -q '192.168.8.190:5900' <<<"$started"; then
  echo "FAIL: Start does not show the Remmina address" >&2
  fail=1
fi
if ! grep -q '^address=127.0.0.1$' "${runtime}/corebrum/wayvnc.conf"; then
  echo "FAIL: wayvnc config is reachable from the network" >&2
  fail=1
fi
if ! grep -q '^port=5901$' "${runtime}/corebrum/wayvnc.conf"; then
  echo "FAIL: wayvnc config does not stay off the Mac port" >&2
  fail=1
fi
if ! grep -q '^testpass$' "${runtime}/corebrum/wayvnc.password"; then
  echo "FAIL: the Screen Sharing password was not saved" >&2
  fail=1
fi
if ! grep -q $'^Password$' <<<"$started"; then
  echo "FAIL: Start does not label the password" >&2
  fail=1
fi
if ! grep -q 'Password: testpass' <<<"$started"; then
  echo "FAIL: Start does not show the Screen Sharing password" >&2
  fail=1
fi

stopped="$(COREBRUM_VNC_READY=1 COREBRUM_VNC_RUNNING=1 COREBRUM_VNC_CHOICE=Stop bash "$menu" open)"
if [[ "$stopped" != "stop wayvnc" ]]; then
  echo "FAIL: Stop does not stop wayvnc (got ${stopped})" >&2
  fail=1
fi

how="$(COREBRUM_VNC_READY=1 COREBRUM_VNC_RUNNING=0 COREBRUM_VNC_CHOICE='How to connect' bash "$menu" open)"
if ! grep -q 'Choose Start in this menu first' <<<"$how"; then
  echo "FAIL: the instructions do not say the server is stopped" >&2
  fail=1
fi
if ! grep -q 'Open Finder' <<<"$how"; then
  echo "FAIL: the Mac instructions skip Finder" >&2
  fail=1
fi
if ! grep -q 'Open TigerVNC Viewer' <<<"$how"; then
  echo "FAIL: the Windows instructions skip TigerVNC Viewer" >&2
  fail=1
fi
if ! grep -q 'Set the protocol to VNC' <<<"$how"; then
  echo "FAIL: the Linux instructions skip the Remmina protocol" >&2
  fail=1
fi

if ! python3 "${ROOT}/scripts/desktop/corebrum-vnc-proxy.py" --self-test; then
  echo "FAIL: the Screen Sharing password handshake failed" >&2
  fail=1
fi

rm -rf "$runtime"
if [[ "$fail" -ne 0 ]]; then
  exit 1
fi
echo "vnc menu unit tests passed"
