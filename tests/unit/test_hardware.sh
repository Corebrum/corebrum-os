#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=../../scripts/lib/hardware.sh
source "${ROOT}/scripts/lib/hardware.sh"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

COREBRUM_TEGRA_RELEASE="${tmp}/no-tegra"
COREBRUM_DEVICE_TREE_MODEL="${tmp}/model"
COREBRUM_DEVICE_TREE_COMPATIBLE="${tmp}/compatible"
export COREBRUM_TEGRA_RELEASE COREBRUM_DEVICE_TREE_MODEL COREBRUM_DEVICE_TREE_COMPATIBLE

printf 'Generic PC\n' >"$COREBRUM_DEVICE_TREE_MODEL"
if corebrum_detect_jetson; then
  echo "FAIL: generic model should not detect Jetson" >&2
  exit 1
fi

printf '# L4T\n' >"$COREBRUM_TEGRA_RELEASE"
if ! corebrum_detect_jetson; then
  echo "FAIL: nv_tegra_release should detect Jetson" >&2
  exit 1
fi

printf '' >"$COREBRUM_TEGRA_RELEASE"
printf 'NVIDIA Jetson Orin Nano Developer Kit' >"$COREBRUM_DEVICE_TREE_MODEL"
if ! corebrum_detect_jetson; then
  echo "FAIL: Jetson model string should detect Jetson" >&2
  exit 1
fi

id="$(corebrum_reference_hardware_id || true)"
if [[ "$id" != "jetson-orin-2wd-jetgpio" ]]; then
  echo "FAIL: expected jetson reference id, got ${id:-empty}" >&2
  exit 1
fi

echo "PASS: hardware detection"