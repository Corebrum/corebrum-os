#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=../../scripts/lib/log.sh
source "${ROOT}/scripts/lib/log.sh"
# shellcheck source=../../scripts/lib/manifest.sh
source "${ROOT}/scripts/lib/manifest.sh"

assert_eq() {
  local got="$1"
  local expected="$2"
  local message="$3"
  if [[ "$got" != "$expected" ]]; then
    printf 'FAIL: %s (got %q expected %q)\n' "$message" "$got" "$expected" >&2
    exit 1
  fi
}

if corebrum_valid_package_name "not a package"; then
  echo "FAIL: invalid package name accepted" >&2
  exit 1
fi
if ! corebrum_valid_package_name "openssh-server"; then
  echo "FAIL: openssh-server rejected" >&2
  exit 1
fi

packages=()
corebrum_load_manifest "${ROOT}/tests/unit/fixtures/packages-ok.txt" packages
assert_eq "${#packages[@]}" "2" "package count"
assert_eq "${packages[0]}" "ca-certificates" "first package"
assert_eq "${packages[1]}" "curl" "second package"

if (corebrum_load_manifest "${ROOT}/tests/unit/fixtures/packages-bad.txt" packages >/dev/null 2>&1); then
  echo "FAIL: invalid manifest was accepted" >&2
  exit 1
fi

desktop=()
corebrum_load_manifest "${ROOT}/manifests/packages/desktop.txt" desktop
assert_eq "${#desktop[@]}" "34" "desktop package count"
assert_eq "${desktop[0]}" "sway" "desktop manifest starts with sway"
found_waybar=0
found_greetd=0
found_mako=0
found_espeak=0
found_editor=0
found_gst=0
found_gst_ugly=0
found_gst_pipewire=0
found_gst_gir=0
found_gst_base_gir=0
for pkg in "${desktop[@]}"; do
  [[ "$pkg" == "waybar" ]] && found_waybar=1
  [[ "$pkg" == "greetd" ]] && found_greetd=1
  [[ "$pkg" == "mako-notifier" ]] && found_mako=1
  [[ "$pkg" == "espeak-ng-espeak" ]] && found_espeak=1
  [[ "$pkg" == "gnome-text-editor" ]] && found_editor=1
  [[ "$pkg" == "gstreamer1.0-tools" ]] && found_gst=1
  [[ "$pkg" == "gstreamer1.0-plugins-ugly" ]] && found_gst_ugly=1
  [[ "$pkg" == "gstreamer1.0-pipewire" ]] && found_gst_pipewire=1
  [[ "$pkg" == "gir1.2-gstreamer-1.0" ]] && found_gst_gir=1
  [[ "$pkg" == "gir1.2-gst-plugins-base-1.0" ]] && found_gst_base_gir=1
done
if [[ "$found_waybar" -ne 1 || "$found_greetd" -ne 1 || "$found_mako" -ne 1 || "$found_espeak" -ne 1 || "$found_editor" -ne 1 ]]; then
  echo "FAIL: desktop manifest is missing waybar, greetd, mako-notifier, espeak-ng-espeak, or gnome-text-editor" >&2
  exit 1
fi
if [[ "$found_gst" -ne 1 || "$found_gst_ugly" -ne 1 || "$found_gst_pipewire" -ne 1 || "$found_gst_gir" -ne 1 || "$found_gst_base_gir" -ne 1 ]]; then
  echo "FAIL: desktop manifest is missing the GStreamer packages AgenticROS desktop uses" >&2
  exit 1
fi

services=()
corebrum_load_manifest "${ROOT}/manifests/packages/services.txt" services
assert_eq "${#services[@]}" "27" "services package count"
for pkg in "${services[@]}"; do
  case "$pkg" in
    grimshot | pulseaudio | tlp | hyprpolkitagent | xdg-desktop-portal-hyprland)
      echo "FAIL: services manifest includes ${pkg}" >&2
      exit 1
      ;;
  esac
done
found_nm=0
found_pipewire=0
found_mate=0
for pkg in "${services[@]}"; do
  [[ "$pkg" == "network-manager" ]] && found_nm=1
  [[ "$pkg" == "pipewire-pulse" ]] && found_pipewire=1
  [[ "$pkg" == "mate-polkit" ]] && found_mate=1
done
if [[ "$found_nm" -ne 1 || "$found_pipewire" -ne 1 || "$found_mate" -ne 1 ]]; then
  echo "FAIL: services manifest is missing network-manager, pipewire-pulse, or mate-polkit" >&2
  exit 1
fi

ros=()
corebrum_load_manifest "${ROOT}/manifests/packages/ros.txt" ros
assert_eq "${#ros[@]}" "6" "ros package count"
for pkg in "${ros[@]}"; do
  case "$pkg" in
    ros-jazzy-desktop | ros-jazzy-rviz2 | ros-jazzy-gazebo-ros-pkgs | ros-jazzy-realsense2-camera)
      echo "FAIL: ros manifest includes ${pkg}" >&2
      exit 1
      ;;
  esac
done
found_zenoh=0
found_base=0
found_dds=0
for pkg in "${ros[@]}"; do
  [[ "$pkg" == "ros-jazzy-ros-base" ]] && found_base=1
  [[ "$pkg" == "ros-jazzy-rmw-zenoh-cpp" ]] && found_zenoh=1
  [[ "$pkg" == "ros-jazzy-rmw-fastrtps-cpp" ]] && found_dds=1
done
if [[ "$found_base" -ne 1 || "$found_zenoh" -ne 1 || "$found_dds" -ne 1 ]]; then
  echo "FAIL: ros manifest is missing ros-base, rmw-zenoh-cpp, or rmw-fastrtps-cpp" >&2
  exit 1
fi

lyrical=()
corebrum_load_manifest "${ROOT}/manifests/packages/ros-lyrical.txt" lyrical
assert_eq "${#lyrical[@]}" "6" "lyrical package count"
found_lyrical_base=0
found_lyrical_zenoh=0
for pkg in "${lyrical[@]}"; do
  case "$pkg" in
    ros-lyrical-desktop | ros-lyrical-rviz2 | ros-jazzy-*)
      echo "FAIL: lyrical manifest includes ${pkg}" >&2
      exit 1
      ;;
  esac
  [[ "$pkg" == "ros-lyrical-ros-base" ]] && found_lyrical_base=1
  [[ "$pkg" == "ros-lyrical-rmw-zenoh-cpp" ]] && found_lyrical_zenoh=1
done
if [[ "$found_lyrical_base" -ne 1 || "$found_lyrical_zenoh" -ne 1 ]]; then
  echo "FAIL: lyrical manifest is missing ros-base or rmw-zenoh-cpp" >&2
  exit 1
fi

echo "ok: manifest"
