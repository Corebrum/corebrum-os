#!/usr/bin/env bash
# About is under Super+Space System. It prints a machine card.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
about="${ROOT}/scripts/desktop/corebrum-about.sh"
menu="${ROOT}/scripts/desktop/corebrum-about-menu.sh"
fail=0

if ! grep -q '/usr/local/bin/corebrum-about-menu refresh' "${ROOT}/scripts/desktop/corebrum-launcher.sh"; then
  echo "FAIL: Super+Space does not refresh About" >&2
  fail=1
fi
if ! grep -q 'corebrum-about-menu.sh' "${ROOT}/scripts/lib/desktop.sh"; then
  echo "FAIL: the desktop install does not copy the About menu" >&2
  fail=1
fi
if ! grep -q 'corebrum-about.sh' "${ROOT}/scripts/lib/desktop.sh"; then
  echo "FAIL: the desktop install does not copy About" >&2
  fail=1
fi
if ! grep -q '/usr/local/bin/corebrum-about-menu' "${ROOT}/scripts/lib/desktop.sh"; then
  echo "FAIL: desktop uninstall does not remove the About menu" >&2
  fail=1
fi
if ! grep -q '/usr/local/bin/corebrum-about' "${ROOT}/scripts/validate/desktop.sh"; then
  echo "FAIL: desktop validation does not check About" >&2
  fail=1
fi
if ! grep -q 'corebrum-about' "${ROOT}/config/menu/corebrum-menu.json"; then
  echo "FAIL: System does not list About" >&2
  fail=1
fi
if ! grep -q 'app_id="org.corebrum.about"' "${ROOT}/config/sway/config"; then
  echo "FAIL: Sway does not float the About window" >&2
  fail=1
fi
if ! grep -q 'about)' "${ROOT}/scripts/corebrum.sh"; then
  echo "FAIL: corebrum about is not wired" >&2
  fail=1
fi

runtime="$(mktemp -d)"
XDG_RUNTIME_DIR="$runtime" bash "$menu" refresh
desktop="${runtime}/corebrum/applications/corebrum-about.desktop"
if ! grep -q '^Name=About$' "$desktop"; then
  echo "FAIL: About is not the menu name" >&2
  fail=1
fi
if ! grep -q '^Exec=/usr/local/bin/corebrum-about-menu open$' "$desktop"; then
  echo "FAIL: About does not open the card" >&2
  fail=1
fi
if ! grep -q '^Icon=/usr/share/corebrum/icon.png$' "$desktop"; then
  echo "FAIL: About does not use the Corebrum icon" >&2
  fail=1
fi
rm -rf "$runtime"

output="$(
  COREBRUM_ABOUT_VERSION=0.5.0 \
  COREBRUM_ABOUT_SYNAPSE=0.7.41 \
  COREBRUM_ABOUT_PC='Test PC' \
  COREBRUM_ABOUT_CPU='Test CPU (4)' \
  COREBRUM_ABOUT_GPU='Test GPU' \
  COREBRUM_ABOUT_DISPLAY='HDMI-A-1 1920x1080' \
  COREBRUM_ABOUT_DISK='10G / 100G (10%)' \
  COREBRUM_ABOUT_MEMORY='2Gi / 8Gi' \
  COREBRUM_ABOUT_SWAP=none \
  COREBRUM_ABOUT_OS='Ubuntu 24.04.5 LTS' \
  COREBRUM_ABOUT_KERNEL='6.8.0-test' \
  COREBRUM_ABOUT_WM=Sway \
  COREBRUM_ABOUT_TERMINAL=Kitty \
  COREBRUM_ABOUT_OS_AGE='12 days' \
  COREBRUM_ABOUT_UPTIME='3 hours, 4 minutes' \
  COREBRUM_ABOUT_UPDATE='2026-10-30  09:40:35' \
  bash "$about" print
)"

for needle in \
  '____   ___   ____   _____  ____   ____   _   _  __  __' \
  ' \____| \___/ |_| \_\|_____||____/ |_| \_\ \___/ |_|  |_|' \
  'Hardware' \
  'PC           Test PC' \
  'CPU          Test CPU (4)' \
  'GPU          Test GPU' \
  'Display      HDMI-A-1 1920x1080' \
  'Disk         10G / 100G (10%)' \
  'Memory       2Gi / 8Gi' \
  'Corebrum     Corebrum 0.5.0' \
  'Synapse      Corebrum Synapse 0.7.41' \
  'OS           Ubuntu 24.04.5 LTS' \
  'Kernel       6.8.0-test' \
  'WM           Sway' \
  'Terminal     Kitty' \
  'OS Age       12 days' \
  'Uptime       3 hours, 4 minutes' \
  'Update       2026-10-30  09:40:35'
do
  if ! grep -Fq "$needle" <<<"$output"; then
    echo "FAIL: card missing ${needle}" >&2
    fail=1
  fi
done
if grep -Fq 'Swap' <<<"$output"; then
  echo "FAIL: swap none still printed a Swap row" >&2
  fail=1
fi

missing="$(
  COREBRUM_ABOUT_VERSION=0.5.0 \
  COREBRUM_ABOUT_SYNAPSE='not installed' \
  COREBRUM_ABOUT_PC=pc \
  COREBRUM_ABOUT_CPU=cpu \
  COREBRUM_ABOUT_GPU=gpu \
  COREBRUM_ABOUT_DISK=disk \
  COREBRUM_ABOUT_MEMORY=mem \
  COREBRUM_ABOUT_SWAP=none \
  COREBRUM_ABOUT_OS=os \
  COREBRUM_ABOUT_KERNEL=kernel \
  COREBRUM_ABOUT_WM=Sway \
  COREBRUM_ABOUT_TERMINAL=Kitty \
  COREBRUM_ABOUT_OS_AGE='1 day' \
  COREBRUM_ABOUT_UPTIME='1 minute' \
  COREBRUM_ABOUT_UPDATE=unknown \
  bash "$about" print
)"
if ! grep -Fq 'Synapse      not installed' <<<"$missing"; then
  echo "FAIL: missing Synapse is not reported" >&2
  fail=1
fi

apt_log="$(mktemp)"
cat >"$apt_log" <<'EOF'
Start-Date: 2026-08-31  16:04:30
Commandline: apt full-upgrade
End-Date: 2026-08-31  16:09:14

Start-Date: 2026-10-13  06:34:39
Commandline: apt upgrade
End-Date: 2026-10-13  06:34:57

Start-Date: 2026-10-30  09:40:35
Commandline: apt upgrade -y
End-Date: 2026-10-30  09:42:41
EOF
stamp="$(
  COREBRUM_ABOUT_VERSION=v \
  COREBRUM_ABOUT_SYNAPSE='not installed' \
  COREBRUM_ABOUT_PC=pc \
  COREBRUM_ABOUT_CPU=cpu \
  COREBRUM_ABOUT_GPU=gpu \
  COREBRUM_ABOUT_DISK=disk \
  COREBRUM_ABOUT_MEMORY=mem \
  COREBRUM_ABOUT_SWAP=none \
  COREBRUM_ABOUT_OS=os \
  COREBRUM_ABOUT_KERNEL=k \
  COREBRUM_ABOUT_WM=Sway \
  COREBRUM_ABOUT_TERMINAL=Kitty \
  COREBRUM_ABOUT_OS_AGE=age \
  COREBRUM_ABOUT_UPTIME=up \
  COREBRUM_ABOUT_APT_HISTORY="$apt_log" \
  bash "$about" print
)"
rm -f "$apt_log"
if ! grep -Fq 'Update       2026-10-30  09:40:35' <<<"$stamp"; then
  echo "FAIL: apt history did not pick the latest upgrade" >&2
  fail=1
fi

stub="$(COREBRUM_ABOUT_STUB=1 bash "$menu" open)"
if [[ "$stub" != "corebrum-about open" ]]; then
  echo "FAIL: About open stub was ${stub}" >&2
  fail=1
fi

if [[ "$fail" -ne 0 ]]; then
  exit 1
fi
echo "PASS: about menu"
