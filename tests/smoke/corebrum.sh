#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CMD="${ROOT}/scripts/corebrum.sh"

version="$("$CMD" version)"
if [[ "$version" != "corebrum 0.5.0" ]]; then
  echo "FAIL: version printed ${version}" >&2
  exit 1
fi

if ! "$CMD" help >/dev/null; then
  echo "FAIL: help should succeed" >&2
  exit 1
fi

if "$CMD" install --dry-run >/dev/null 2>&1; then
  echo "FAIL: install without a profile should fail" >&2
  exit 1
fi

if "$CMD" install robotics --dry-run >/dev/null 2>&1; then
  echo "FAIL: robotics profile should be rejected" >&2
  exit 1
fi

home_tmp="$(mktemp -d)"
trap 'rm -rf "$home_tmp"' EXIT
if ! HOME="$home_tmp" "$CMD" config >/dev/null; then
  echo "FAIL: config should succeed" >&2
  exit 1
fi
if [[ -n "$(find "$home_tmp" -mindepth 1 -print -quit)" ]]; then
  echo "FAIL: config wrote into HOME" >&2
  exit 1
fi

status="$("$CMD" status)"
if ! grep -q 'profile base:' <<<"$status"; then
  echo "FAIL: status did not report the base profile" >&2
  exit 1
fi
if ! grep -q 'profile ros:' <<<"$status"; then
  echo "FAIL: status did not report the ros profile" >&2
  exit 1
fi
for line in 'realsense:' 'synapse:' 'skills helper:' 'speech:'; do
  if ! grep -q "$line" <<<"$status"; then
    echo "FAIL: status did not report ${line}" >&2
    exit 1
  fi
done
if ! "$CMD" ros status >/dev/null; then
  echo "FAIL: ros status should succeed before ROS is required" >&2
  exit 1
fi

desktop="$("$CMD" install desktop --dry-run 2>&1)"
if ! grep -q 'workstation services dry-run complete' <<<"$desktop"; then
  printf '%s\n' "$desktop" >&2
  echo "FAIL: corebrum install desktop --dry-run did not finish" >&2
  exit 1
fi
if ! grep -q 'link /usr/local/bin/corebrum' <<<"$desktop"; then
  echo "FAIL: dry-run did not link the corebrum command" >&2
  exit 1
fi
if ! grep -q 'not changing existing Netplan files or running netplan apply' <<<"$desktop"; then
  echo "FAIL: dry-run did not keep the Netplan promise" >&2
  exit 1
fi
if grep -q 'ros-jazzy-ros-base' <<<"$desktop"; then
  echo "FAIL: desktop dry-run listed ROS packages" >&2
  exit 1
fi

headless="$("$CMD" install headless --dry-run 2>&1)"
if ! grep -q 'headless profile is the base profile' <<<"$headless"; then
  echo "FAIL: headless was not mapped to the base profile" >&2
  exit 1
fi
if ! grep -q 'base profile dry-run complete' <<<"$headless"; then
  echo "FAIL: headless dry-run did not finish the base profile" >&2
  exit 1
fi

again="$("$CMD" install desktop --dry-run 2>&1)"
if ! grep -q 'workstation services dry-run complete' <<<"$again"; then
  echo "FAIL: second desktop dry-run did not finish" >&2
  exit 1
fi

ros="$("$CMD" install ros --dry-run 2>&1)"
if ! grep -q 'ros profile dry-run complete' <<<"$ros"; then
  printf '%s\n' "$ros" >&2
  echo "FAIL: ros dry-run did not finish" >&2
  exit 1
fi
if ! grep -Eq 'ros-(jazzy|lyrical)-rmw-zenoh-cpp' <<<"$ros"; then
  echo "FAIL: ros dry-run did not list the Zenoh RMW" >&2
  exit 1
fi
if ! grep -q 'not running apt upgrade' <<<"$ros"; then
  echo "FAIL: ros dry-run did not refuse apt upgrade" >&2
  exit 1
fi
if grep -Eq 'ros-(jazzy|lyrical)-desktop|ros-(jazzy|lyrical)-rviz2' <<<"$ros"; then
  echo "FAIL: ros dry-run listed RViz or the ROS desktop metapackage" >&2
  exit 1
fi

if grep -q '^prompt=' "${ROOT}/config/fuzzel/fuzzel.ini"; then
  echo "FAIL: Super+Space fuzzel.ini sets a search prompt" >&2
  exit 1
fi
if ! grep -q -- "--prompt ''" "${ROOT}/scripts/desktop/corebrum-launcher.sh"; then
  echo "FAIL: Super+Space search prompt is not blank" >&2
  exit 1
fi
if ! grep -q '^Name=Corebrum$' "${ROOT}/apps/corebrum-grid.desktop"; then
  echo "FAIL: application menu entry is not named Corebrum" >&2
  exit 1
fi
if ! grep -q '^NoDisplay=true$' "${ROOT}/apps/corebrum-grid.desktop"; then
  echo "FAIL: the app grid is listed in Fuzzel as well as Super+Alt+Space" >&2
  exit 1
fi

if [[ -f /etc/corebrum/sway/config || -f /etc/corebrum/hypr/hyprland.conf ]]; then
  if ! doctor_out="$("$CMD" doctor 2>&1)"; then
    printf '%s\n' "$doctor_out" >&2
    echo "FAIL: doctor failed on an installed desktop" >&2
    exit 1
  fi
fi

echo "ok: corebrum"
