#!/usr/bin/env bash
# Pick the main panel and optional Touch Bar backlight. Source only.

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  echo "source scripts/lib/backlight.sh from another script" >&2
  exit 1
fi

corebrum_backlight_class_dir() {
  printf '%s\n' /sys/class/backlight
}

# Prefer the internal panel over the Mac Touch Bar backlight (appletb_backlight).
corebrum_backlight_display_device() {
  local candidate path name
  for candidate in amdgpu_bl* intel_backlight apple-panel-bl acpi_video*; do
    for path in "$(corebrum_backlight_class_dir)"/$candidate; do
      [[ -e "$path" ]] || continue
      basename "$path"
      return 0
    done
  done
  for path in "$(corebrum_backlight_class_dir)"/*; do
    [[ -e "$path" ]] || continue
    name="$(basename "$path")"
    case "$name" in
      appletb_backlight) continue ;;
    esac
    printf '%s\n' "$name"
    return 0
  done
  return 1
}

corebrum_backlight_touchbar_device() {
  if [[ -e "$(corebrum_backlight_class_dir)/appletb_backlight" ]]; then
    printf '%s\n' appletb_backlight
    return 0
  fi
  return 1
}