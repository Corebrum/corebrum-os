#!/usr/bin/env bash
# Voice is under Super+Space Setup. It tests speak, picks a mic, and hears.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
menu="${ROOT}/scripts/desktop/corebrum-voice-menu.sh"
fail=0

assert_grep() {
  local pattern="$1" file="$2" message="$3"
  if ! grep -qE -e "$pattern" "$file"; then
    echo "FAIL: ${message}" >&2
    fail=1
  fi
}

assert_grep 'corebrum-voice-menu refresh' "${ROOT}/scripts/desktop/corebrum-launcher.sh" "launcher does not refresh Voice"
assert_grep 'corebrum-voice-menu.sh' "${ROOT}/scripts/lib/desktop.sh" "desktop install does not install the Voice menu"
assert_grep '/usr/local/bin/corebrum-voice-menu' "${ROOT}/scripts/lib/desktop.sh" "desktop uninstall does not remove the Voice menu"
assert_grep '/usr/local/bin/corebrum-voice-menu' "${ROOT}/scripts/validate/desktop.sh" "desktop validator does not require the Voice menu"
assert_grep 'corebrum-voice' "${ROOT}/config/menu/corebrum-menu.json" "Setup does not list Voice"
assert_grep '"corebrum-voice"' "${ROOT}/config/menu/corebrum-menu.json" "Voice is not a dynamic Setup leaf"
assert_grep 'corebrum voice mic set' "$menu" "Voice menu does not set a microphone"
assert_grep 'voice hear --install' "$menu" "Voice menu does not install recognition"
assert_grep 'voice test' "$menu" "Voice menu does not test speak"
if grep -q 'gnome-control-center' "$menu"; then
  echo "FAIL: Voice launches GNOME Control Center" >&2
  fail=1
fi
if ! grep -q 'Setup then Voice' "${ROOT}/config/getting-started/desktop.html"; then
  echo "FAIL: Getting Started desktop page does not mention Voice" >&2
  fail=1
fi
if ! grep -q 'voice mic list' "${ROOT}/config/getting-started/corebrum-cli.html"; then
  echo "FAIL: Getting Started CLI page does not mention voice mic" >&2
  fail=1
fi
if [[ ! -f "${ROOT}/docs/decisions/0122-voice-menu-mic.md" ]]; then
  echo "FAIL: decision 0122 is missing" >&2
  fail=1
fi
assert_grep 'voice list\|test\|set\|mic\|hear' "${ROOT}/scripts/corebrum.sh" "corebrum help omits voice mic"

runtime="$(mktemp -d)"
export XDG_RUNTIME_DIR="$runtime"
export COREBRUM_VOICE_STUB=1

labels="$(bash "$menu" labels)"
expected=$'Test speak\nHear once\nMicrophone\nInstall recognition\nEnable speech\nDisable speech'
if [[ "$labels" != "$expected" ]]; then
  echo "FAIL: labels were ${labels}" >&2
  fail=1
fi

export COREBRUM_VOICE_CHOICE="Test speak"
output="$(bash "$menu" open)"
if [[ "$output" != "corebrum voice test" ]]; then
  echo "FAIL: Test speak stub was ${output}" >&2
  fail=1
fi

export COREBRUM_VOICE_CHOICE="Microphone"
export COREBRUM_VOICE_MIC_LINES=$'alsa_input.usb\tUSB Mic'
export COREBRUM_VOICE_MIC_CHOICE="USB Mic  (alsa_input.usb)"
output="$(bash "$menu" open)"
if [[ "$output" != "corebrum voice mic set alsa_input.usb" ]]; then
  echo "FAIL: Microphone stub was ${output}" >&2
  fail=1
fi
unset COREBRUM_VOICE_CHOICE COREBRUM_VOICE_MIC_CHOICE COREBRUM_VOICE_MIC_LINES

bash "$menu" refresh
desktop="${runtime}/corebrum/applications/corebrum-voice.desktop"
if ! grep -q '^Name=Voice$' "$desktop"; then
  echo "FAIL: desktop Name was $(grep '^Name=' "$desktop" || true)" >&2
  fail=1
fi
if ! grep -q '^Keywords=voice;speech;microphone;mic;transcribe;espeak;pocketsphinx;$' "$desktop"; then
  echo "FAIL: search keywords missing on Voice desktop" >&2
  fail=1
fi
if ! grep -q '^Exec=/usr/local/bin/corebrum-voice-menu open$' "$desktop"; then
  echo "FAIL: desktop does not open Voice" >&2
  fail=1
fi

rm -rf "$runtime"

if [[ "$fail" -ne 0 ]]; then
  exit 1
fi
echo "PASS: voice menu"
