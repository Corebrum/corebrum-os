#!/usr/bin/env bash
# Super+Space wallpaper list. hyprpaper is installed with the desktop.
set -euo pipefail

COREBRUM_WALLPAPER_LIB_DIR="${COREBRUM_WALLPAPER_LIB_DIR:-/usr/share/hypr}"
COREBRUM_WALLPAPER_PICTURES="${COREBRUM_WALLPAPER_PICTURES:-${HOME}/Pictures}"

corebrum_wallpaper_menu_die() {
  printf 'corebrum-wallpaper-menu: %s\n' "$1" >&2
  exit 1
}

corebrum_wallpaper_menu_entry_name() {
  printf 'Wallpaper\n'
}

corebrum_wallpaper_menu_data_dir() {
  local root="${XDG_RUNTIME_DIR:-/tmp/corebrum-launcher-${UID}}"
  printf '%s\n' "${root}/corebrum"
}

corebrum_wallpaper_menu_state_dir() {
  local root="${XDG_STATE_HOME:-${HOME}/.local/state}"
  printf '%s\n' "${root}/corebrum"
}

corebrum_wallpaper_menu_refresh() {
  local dir name
  dir="$(corebrum_wallpaper_menu_data_dir)/applications"
  name="$(corebrum_wallpaper_menu_entry_name)"
  mkdir -p "$dir"
  rm -f "${dir}/corebrum-waypaper.desktop"
  cat >"${dir}/corebrum-wallpaper.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=${name}
GenericName=${name}
Comment=Choose a desktop wallpaper
Exec=/usr/local/bin/corebrum-wallpaper-menu open
Icon=preferences-desktop-wallpaper
Terminal=false
Categories=Settings;DesktopSettings;
StartupNotify=false
EOF
}

corebrum_wallpaper_menu_is_image() {
  local name="${1,,}"
  case "$name" in
    *.png | *.jpg | *.jpeg | *.webp) return 0 ;;
    *) return 1 ;;
  esac
}

# Print "label<TAB>path" for each image. Corebrum walls come first.
corebrum_wallpaper_menu_images() {
  local path base label dir nullglob_was=0
  local -a user_paths=()
  declare -A seen=()

  if shopt -q nullglob; then
    nullglob_was=1
  fi
  shopt -s nullglob
  for path in "${COREBRUM_WALLPAPER_LIB_DIR}"/wall*.png; do
    [[ -f "$path" ]] || continue
    base="$(basename "$path")"
    label="Corebrum ${base}"
    seen["$label"]=1
    printf '%s\t%s\n' "$label" "$path"
  done
  if [[ "$nullglob_was" -eq 0 ]]; then
    shopt -u nullglob
  fi

  for dir in "$COREBRUM_WALLPAPER_PICTURES" "${COREBRUM_WALLPAPER_PICTURES}/Wallpapers"; do
    [[ -d "$dir" ]] || continue
    while IFS= read -r path; do
      [[ -n "$path" ]] || continue
      corebrum_wallpaper_menu_is_image "$(basename "$path")" || continue
      user_paths+=("$path")
    done < <(find "$dir" -maxdepth 1 -type f | sort)
  done

  for path in "${user_paths[@]}"; do
    base="$(basename "$path")"
    label="$base"
    if [[ -n "${seen[$label]:-}" ]]; then
      label="$(basename "$(dirname "$path")")/${base}"
    fi
    seen["$label"]=1
    printf '%s\t%s\n' "$label" "$path"
  done
}

corebrum_wallpaper_menu_labels() {
  local line
  while IFS= read -r line; do
    printf '%s\n' "${line%%$'\t'*}"
  done
}

corebrum_wallpaper_menu_add_label() {
  printf 'Add image\n'
}

# Copy a chosen PNG, JPEG, or WebP into ~/Pictures/Wallpapers.
corebrum_wallpaper_menu_pick() {
  if [[ "${COREBRUM_WALLPAPER_STUB:-0}" == 1 ]]; then
    printf '%s\n' "${COREBRUM_WALLPAPER_ADD:-}"
    return 0
  fi
  if ! command -v python3 >/dev/null 2>&1; then
    corebrum_wallpaper_menu_die "python3 is required to choose a wallpaper"
  fi
  python3 - <<'PY'
import sys

import gi

gi.require_version("Gtk", "3.0")
from gi.repository import Gtk

dialog = Gtk.FileChooserDialog(
    title="Add wallpaper",
    action=Gtk.FileChooserAction.OPEN,
)
dialog.add_buttons("_Cancel", Gtk.ResponseType.CANCEL, "_Open", Gtk.ResponseType.ACCEPT)
images = Gtk.FileFilter()
images.set_name("Images")
for pattern in ("*.png", "*.jpg", "*.jpeg", "*.webp", "*.PNG", "*.JPG", "*.JPEG", "*.WEBP"):
    images.add_pattern(pattern)
dialog.add_filter(images)
if dialog.run() == Gtk.ResponseType.ACCEPT:
    name = dialog.get_filename()
    if name:
        sys.stdout.write(name + "\n")
dialog.destroy()
PY
}

corebrum_wallpaper_menu_import() {
  local src dest dir base stem ext n
  src="$(corebrum_wallpaper_menu_pick)"
  [[ -n "$src" ]] || return 0
  [[ -f "$src" ]] || corebrum_wallpaper_menu_die "wallpaper image is missing"
  corebrum_wallpaper_menu_is_image "$(basename "$src")" \
    || corebrum_wallpaper_menu_die "wallpaper must be a png, jpg, or webp"
  dir="${COREBRUM_WALLPAPER_PICTURES}/Wallpapers"
  mkdir -p "$dir"
  base="$(basename "$src")"
  dest="${dir}/${base}"
  if [[ -e "$dest" && "$(readlink -f "$src")" != "$(readlink -f "$dest")" ]]; then
    stem="${base%.*}"
    ext="${base##*.}"
    n=2
    while [[ -e "${dir}/${stem}-${n}.${ext}" ]]; do
      n=$((n + 1))
    done
    dest="${dir}/${stem}-${n}.${ext}"
  fi
  if [[ "$(readlink -f "$src")" != "$(readlink -f "$dest")" ]]; then
    cp -- "$src" "$dest"
  fi
  corebrum_wallpaper_menu_apply "$dest"
}

corebrum_wallpaper_menu_config() {
  local path="$1"
  # hyprpaper 0.8.3 drops a wallpaper block with an empty monitor name, and it
  # keeps quotation marks as part of the path. * matches every monitor.
  cat <<EOF
splash = false

wallpaper {
    monitor = *
    path = ${path}
    fit_mode = cover
}
EOF
}

corebrum_wallpaper_menu_apply() {
  local path="$1" dir cfg
  case "$path" in
    *\"* | *$'\n'*) corebrum_wallpaper_menu_die "wallpaper path cannot be stored" ;;
  esac
  [[ -f "$path" ]] || corebrum_wallpaper_menu_die "wallpaper image is missing"
  dir="$(corebrum_wallpaper_menu_state_dir)"
  cfg="${dir}/hyprpaper.conf"
  if [[ "${COREBRUM_WALLPAPER_STUB:-0}" == 1 ]]; then
    mkdir -p "$dir"
    corebrum_wallpaper_menu_config "$path" >"$cfg"
    printf '%s\n' "$path"
    return 0
  fi
  mkdir -p "$dir"
  corebrum_wallpaper_menu_config "$path" >"${cfg}.tmp"
  mv "${cfg}.tmp" "$cfg"
  if pgrep -x swaybg >/dev/null 2>&1; then
    pkill -x swaybg || true
  fi
  if pgrep -x waypaper >/dev/null 2>&1; then
    pkill -x waypaper || true
  fi
  if pgrep -x hyprpaper >/dev/null 2>&1; then
    pkill -x hyprpaper || true
    local _
    for _ in 1 2 3 4 5 6 7 8 9 10; do
      if ! pgrep -x hyprpaper >/dev/null 2>&1; then
        break
      fi
      sleep 0.1
    done
  fi
  if ! command -v hyprpaper >/dev/null 2>&1; then
    corebrum_wallpaper_menu_die "hyprpaper is installed with the desktop and is not on PATH"
  fi
  setsid --fork -- hyprpaper --config "$cfg" </dev/null >/dev/null 2>&1
}

corebrum_wallpaper_menu_open() {
  local choice line label path
  local -a rows=("$(corebrum_wallpaper_menu_add_label)"$'\t')
  while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    rows+=("$line")
  done < <(corebrum_wallpaper_menu_images)

  if [[ "${COREBRUM_WALLPAPER_STUB:-0}" == 1 && -z "${COREBRUM_WALLPAPER_CHOICE:-}" ]]; then
    printf '%s\n' "${rows[@]}" | corebrum_wallpaper_menu_labels
    return 0
  fi

  if [[ "${COREBRUM_WALLPAPER_STUB:-0}" == 1 ]]; then
    choice="$COREBRUM_WALLPAPER_CHOICE"
  else
    local lines=12
    if [[ "${#rows[@]}" -lt "$lines" ]]; then
      lines="${#rows[@]}"
    fi
    choice="$(printf '%s\n' "${rows[@]}" | corebrum_wallpaper_menu_labels | fuzzel \
      --config /etc/corebrum/fuzzel/fuzzel.ini \
      --dmenu \
      --prompt 'Wallpaper  ' \
      --width 40 \
      --lines "$lines")" || return 0
  fi

  [[ -n "$choice" ]] || return 0
  if [[ "$choice" == "$(corebrum_wallpaper_menu_add_label)" ]]; then
    corebrum_wallpaper_menu_import
    return 0
  fi
  for line in "${rows[@]}"; do
    label="${line%%$'\t'*}"
    path="${line#*$'\t'}"
    if [[ "$label" == "$choice" ]]; then
      corebrum_wallpaper_menu_apply "$path"
      return 0
    fi
  done
  corebrum_wallpaper_menu_die "unknown wallpaper choice"
}

usage() {
  cat <<'EOF'
Usage: corebrum-wallpaper-menu refresh|open|entry-name|data-dir|images
EOF
}

cmd="${1:-}"
case "$cmd" in
  refresh) corebrum_wallpaper_menu_refresh ;;
  open) corebrum_wallpaper_menu_open ;;
  entry-name) corebrum_wallpaper_menu_entry_name ;;
  data-dir) corebrum_wallpaper_menu_data_dir ;;
  images) corebrum_wallpaper_menu_images ;;
  -h | --help | help) usage ;;
  *)
    usage >&2
    exit 1
    ;;
esac
