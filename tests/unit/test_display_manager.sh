#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export COREBRUM_ROOT="$ROOT"
# shellcheck source=../../scripts/lib/log.sh
source "${ROOT}/scripts/lib/log.sh"
# shellcheck source=../../scripts/lib/desktop.sh
source "${ROOT}/scripts/lib/desktop.sh"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
DRY_RUN=0
COREBRUM_STATE_FILE="${tmp}/state"
COREBRUM_DISPLAY_MANAGER_LINK="${tmp}/display-manager.service"
COREBRUM_TEGRA_RELEASE="${tmp}/no-such-tegra-release"
COREBRUM_DEVICE_TREE_MODEL="${tmp}/model"
COREBRUM_DEVICE_TREE_COMPATIBLE="${tmp}/no-such-compatible"
export DRY_RUN COREBRUM_STATE_FILE COREBRUM_DISPLAY_MANAGER_LINK
export COREBRUM_TEGRA_RELEASE COREBRUM_DEVICE_TREE_MODEL COREBRUM_DEVICE_TREE_COMPATIBLE

systemctl() {
  printf '%s\n' "$*" >>"${tmp}/systemctl.log"
  if [[ "$1" == "get-default" ]]; then
    printf '%s\n' "multi-user.target"
  fi
}

mkdir -p "${tmp}/units"
printf '[Unit]\nDescription=GDM\n' >"${tmp}/units/gdm3.service"

reset_link() {
  rm -f "$COREBRUM_DISPLAY_MANAGER_LINK" "$COREBRUM_STATE_FILE" "${tmp}/systemctl.log"
  ln -s "${tmp}/units/gdm3.service" "$COREBRUM_DISPLAY_MANAGER_LINK"
}

assert_existing_path() {
  local label="$1"
  if [[ "$(readlink "$COREBRUM_DISPLAY_MANAGER_LINK")" != "${tmp}/units/gdm3.service" ]]; then
    echo "FAIL: ${label} changed the existing display manager symlink" >&2
    exit 1
  fi
  if [[ -f "$COREBRUM_STATE_FILE" ]] && grep -q '^previous_display_manager=' "$COREBRUM_STATE_FILE"; then
    echo "FAIL: ${label} recorded a previous display manager" >&2
    exit 1
  fi
  if ! grep -qx 'enable greetd.service' "${tmp}/systemctl.log"; then
    echo "FAIL: ${label} did not enable greetd" >&2
    exit 1
  fi
  if ! grep -qx 'set-default graphical.target' "${tmp}/systemctl.log"; then
    echo "FAIL: ${label} did not set graphical.target" >&2
    exit 1
  fi
}

printf 'Generic x86-64\n' >"$COREBRUM_DEVICE_TREE_MODEL"
reset_link
corebrum_enable_desktop_login
assert_existing_path "x86-64"

printf 'Raspberry Pi 5 Model B Rev 1.0\n' >"$COREBRUM_DEVICE_TREE_MODEL"
reset_link
corebrum_enable_desktop_login
assert_existing_path "Raspberry Pi"

DRY_RUN=1
reset_link
dry_log="$(corebrum_enable_desktop_login 2>&1)"
DRY_RUN=0
if grep -q 'display-manager.service' <<<"$dry_log"; then
  echo "FAIL: Raspberry Pi dry-run mentioned the Jetson display manager step" >&2
  printf '%s\n' "$dry_log" >&2
  exit 1
fi
if [[ "$(readlink "$COREBRUM_DISPLAY_MANAGER_LINK")" != "${tmp}/units/gdm3.service" ]]; then
  echo "FAIL: Raspberry Pi dry-run changed the display manager symlink" >&2
  exit 1
fi

assert_jetson_path() {
  local label="$1"
  if [[ -e "$COREBRUM_DISPLAY_MANAGER_LINK" || -L "$COREBRUM_DISPLAY_MANAGER_LINK" ]]; then
    echo "FAIL: ${label} left the other display manager symlink in place" >&2
    exit 1
  fi
  if [[ "$(corebrum_state_get previous_display_manager)" != "${tmp}/units/gdm3.service" ]]; then
    echo "FAIL: ${label} did not record the previous display manager" >&2
    exit 1
  fi
  if ! grep -qx 'enable greetd.service' "${tmp}/systemctl.log"; then
    echo "FAIL: ${label} did not enable greetd" >&2
    exit 1
  fi
  if ! grep -qx 'set-default graphical.target' "${tmp}/systemctl.log"; then
    echo "FAIL: ${label} did not set graphical.target" >&2
    exit 1
  fi
}

printf 'NVIDIA Jetson AGX Orin Developer Kit' >"$COREBRUM_DEVICE_TREE_MODEL"
reset_link
corebrum_enable_desktop_login
assert_jetson_path "AGX Orin"

printf 'NVIDIA Jetson Orin Nano Developer Kit' >"$COREBRUM_DEVICE_TREE_MODEL"
reset_link
corebrum_enable_desktop_login
assert_jetson_path "Orin Nano"

printf 'NVIDIA Jetson AGX Thor Developer Kit' >"$COREBRUM_DEVICE_TREE_MODEL"
reset_link
corebrum_enable_desktop_login
assert_jetson_path "Thor"

printf 'Custom carrier\n' >"$COREBRUM_DEVICE_TREE_MODEL"
printf '%s' $'nvidia,p4071-0080+p3834-0008\0nvidia,tegra264\0' >"${tmp}/compatible"
COREBRUM_DEVICE_TREE_COMPATIBLE="${tmp}/compatible"
export COREBRUM_DEVICE_TREE_COMPATIBLE
reset_link
corebrum_enable_desktop_login
assert_jetson_path "Thor compatible"
COREBRUM_DEVICE_TREE_COMPATIBLE="${tmp}/no-such-compatible"
export COREBRUM_DEVICE_TREE_COMPATIBLE

printf '# R39 (release), REVISION: 2.1\n' >"${tmp}/nv_tegra_release"
COREBRUM_TEGRA_RELEASE="${tmp}/nv_tegra_release"
export COREBRUM_TEGRA_RELEASE
printf 'Raspberry Pi 5 Model B Rev 1.0\n' >"$COREBRUM_DEVICE_TREE_MODEL"
reset_link
corebrum_enable_desktop_login
if [[ -e "$COREBRUM_DISPLAY_MANAGER_LINK" || -L "$COREBRUM_DISPLAY_MANAGER_LINK" ]]; then
  echo "FAIL: L4T release file left the other display manager symlink in place" >&2
  exit 1
fi

ln -s /lib/systemd/system/greetd.service "$COREBRUM_DISPLAY_MANAGER_LINK"
: >"${tmp}/systemctl.log"
corebrum_enable_desktop_login
if [[ "$(readlink "$COREBRUM_DISPLAY_MANAGER_LINK")" != "/lib/systemd/system/greetd.service" ]]; then
  echo "FAIL: a greetd display-manager symlink was replaced" >&2
  exit 1
fi
if [[ "$(grep -c '^previous_display_manager=' "$COREBRUM_STATE_FILE")" -ne 1 ]]; then
  echo "FAIL: previous display manager was recorded again" >&2
  exit 1
fi

rm -f "$COREBRUM_DISPLAY_MANAGER_LINK"
corebrum_restore_display_manager
if [[ "$(readlink "$COREBRUM_DISPLAY_MANAGER_LINK")" != "${tmp}/units/gdm3.service" ]]; then
  echo "FAIL: Jetson uninstall did not restore the recorded display manager" >&2
  exit 1
fi

ln -s /lib/systemd/system/greetd.service "${tmp}/kept.service"
COREBRUM_DISPLAY_MANAGER_LINK="${tmp}/kept.service"
export COREBRUM_DISPLAY_MANAGER_LINK
corebrum_restore_display_manager
if [[ "$(readlink "$COREBRUM_DISPLAY_MANAGER_LINK")" != "/lib/systemd/system/greetd.service" ]]; then
  echo "FAIL: restore replaced a display-manager symlink that was still present" >&2
  exit 1
fi

echo "ok: display-manager"
