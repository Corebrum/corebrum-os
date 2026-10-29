#!/usr/bin/env bash
# DRM helpers shared by the greeter, the session, and the lock screen.
# Source this file; do not execute it.
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  echo "source scripts/desktop/corebrum-drm.sh from another script" >&2
  exit 1
fi

corebrum_source_vc4() {
  local here lib
  here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  if [[ -f "${here}/../lib/vc4.sh" ]]; then
    lib="${here}/../lib/vc4.sh"
  elif [[ -f "${here}/vc4.sh" ]]; then
    lib="${here}/vc4.sh"
  elif [[ -f /usr/local/lib/corebrum/vc4.sh ]]; then
    lib="/usr/local/lib/corebrum/vc4.sh"
  else
    printf '%s\n' "corebrum: missing vc4 helper" >&2
    return 1
  fi
  # shellcheck source=../lib/vc4.sh
  source "$lib"
}

# Export the scanout device when this machine is a Raspberry Pi. A missing
# vc4 node leaves the environment unchanged, which is the x86_64 path.
corebrum_export_vc4_devices() {
  local card
  corebrum_source_vc4 || return 1
  if ! card="$(corebrum_vc4_card)"; then
    return 0
  fi
  export AQ_DRM_DEVICES="$card"
  export WLR_DRM_DEVICES="$card"
  export WLR_NO_HARDWARE_CURSORS=1
}

# Sway 1.9 exits when /proc/modules has a line starting with "nvidia ".
# --unsupported-gpu is the switch that main.c documents. nvidia_drm and
# nouveau do not match. COREBRUM_PROC_MODULES overrides the file in tests.
# Hardware cursors on that driver fail to pick a format.
corebrum_prepare_nvidia_sway() {
  local modules="${COREBRUM_PROC_MODULES:-/proc/modules}"
  if [[ -r "$modules" ]] && grep -q '^nvidia ' "$modules"; then
    export WLR_NO_HARDWARE_CURSORS=1
    return 0
  fi
  return 1
}

# Copy the system Hyprland config and add the Pi scanout device. The system
# file stays unchanged so an x86_64 install keeps the same config bytes.
corebrum_hyprland_config() {
  local base="$1"
  local card runtime generated
  declare -F corebrum_vc4_card >/dev/null 2>&1 || corebrum_source_vc4 || return 1
  if ! card="$(corebrum_vc4_card)"; then
    printf '%s\n' "$base"
    return 0
  fi
  runtime="${XDG_RUNTIME_DIR:-/tmp}"
  mkdir -p "$runtime"
  generated="${runtime}/corebrum-hyprland.conf"
  cat "$base" >"$generated"
  cat >>"$generated" <<EOF

# Raspberry Pi HDMI scanout. card0 is v3d and has no connector.
env = AQ_DRM_DEVICES,${card}
cursor {
    no_hardware_cursors = true
}
EOF
  printf '%s\n' "$generated"
}
