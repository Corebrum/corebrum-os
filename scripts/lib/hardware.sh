#!/usr/bin/env bash
# Hardware detection for Physical AI profiles. Source only.
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  echo "source scripts/lib/hardware.sh from another script" >&2
  exit 1
fi

# Tests may override these paths.
COREBRUM_TEGRA_RELEASE="${COREBRUM_TEGRA_RELEASE:-/etc/nv_tegra_release}"
COREBRUM_DEVICE_TREE_MODEL="${COREBRUM_DEVICE_TREE_MODEL:-/proc/device-tree/model}"
COREBRUM_DEVICE_TREE_COMPATIBLE="${COREBRUM_DEVICE_TREE_COMPATIBLE:-/proc/device-tree/compatible}"

corebrum_read_device_tree_model() {
  if [[ ! -r "$COREBRUM_DEVICE_TREE_MODEL" ]]; then
    return 1
  fi
  tr -d '\0' <"$COREBRUM_DEVICE_TREE_MODEL"
}

corebrum_read_device_tree_compatible() {
  if [[ ! -r "$COREBRUM_DEVICE_TREE_COMPATIBLE" ]]; then
    return 1
  fi
  tr '\0' ' ' <"$COREBRUM_DEVICE_TREE_COMPATIBLE"
}

corebrum_detect_jetson() {
  if [[ -r "$COREBRUM_TEGRA_RELEASE" ]]; then
    return 0
  fi
  local model compatible
  model="$(corebrum_read_device_tree_model 2>/dev/null || true)"
  if [[ "$model" == *Jetson* ]]; then
    return 0
  fi
  compatible="$(corebrum_read_device_tree_compatible 2>/dev/null || true)"
  if [[ "$compatible" == *nvidia,tegra* ]]; then
    return 0
  fi
  return 1
}

corebrum_reference_hardware_id() {
  if corebrum_detect_jetson; then
    printf '%s\n' "jetson-orin-2wd-jetgpio"
    return 0
  fi
  return 1
}