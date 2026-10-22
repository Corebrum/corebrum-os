#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CMD="${ROOT}/scripts/corebrum.sh"

version="$("$CMD" version)"
if [[ "$version" != "corebrum 0.4.0" ]]; then
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

if ! grep -q '^prompt=Corebrum ' "${ROOT}/config/fuzzel/fuzzel.ini"; then
  echo "FAIL: fuzzel prompt is not Corebrum" >&2
  exit 1
fi
if ! grep -q '^Name=Corebrum$' "${ROOT}/apps/corebrum-grid.desktop"; then
  echo "FAIL: application menu entry is not named Corebrum" >&2
  exit 1
fi

if [[ -f /etc/corebrum/hypr/hyprland.conf ]]; then
  if ! doctor_out="$("$CMD" doctor 2>&1)"; then
    printf '%s\n' "$doctor_out" >&2
    echo "FAIL: doctor failed on an installed desktop" >&2
    exit 1
  fi
fi

echo "ok: corebrum"
