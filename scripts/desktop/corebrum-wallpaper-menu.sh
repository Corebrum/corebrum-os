#!/usr/bin/env bash
# Super+Space wallpaper list. Installs Ubuntu hyprpaper, then sets one image.
set -euo pipefail

COREBRUM_WALLPAPER_INSTALL_MARK='   install'
COREBRUM_WALLPAPER_LIB_DIR="${COREBRUM_WALLPAPER_LIB_DIR:-/usr/share/hypr}"
COREBRUM_WALLPAPER_PICTURES="${COREBRUM_WALLPAPER_PICTURES:-${HOME}/Pictures}"

corebrum_wallpaper_menu_die() {
  printf 'corebrum-wallpaper-menu: %s\n' "$1" >&2
  exit 1
}

corebrum_wallpaper_menu_ready() {
  if [[ "${COREBRUM_WALLPAPER_STUB:-0}" == 1 ]]; then
    [[ "${COREBRUM_WALLPAPER_READY:-0}" == 1 ]]
    return
  fi
  command -v hyprpaper >/dev/null 2>&1
}

corebrum_wallpaper_menu_entry_name() {
  if corebrum_wallpaper_menu_ready; then
    printf 'Wallpaper\n'
  else
    printf 'Wallpaper%s\n' "$COREBRUM_WALLPAPER_INSTALL_MARK"
  fi
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

# Print "label<TAB>path" for each image. Hyprland walls come first.
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
    label="Hyprland ${base}"
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

corebrum_wallpaper_menu_terminal() {
  local script="$1"
  if [[ "${COREBRUM_WALLPAPER_STUB:-0}" == 1 ]]; then
    printf '%s\n' "$script"
    return 0
  fi
  exec /usr/local/bin/corebrum-terminal bash -c "$script"
}

corebrum_wallpaper_menu_install_script() {
  cat <<'EOF'
set +e
candidate=$(apt-cache policy hyprpaper | awk '/Candidate:/ { print $2; exit }')
if [ -z "$candidate" ] || [ "$candidate" = "(none)" ]; then
  printf '%s\n' "hyprpaper is not in this Ubuntu archive."
  printf '\n'
  read -r -p 'Press Enter to close. '
  exit 0
fi
sudo apt-get update && sudo apt-get install -y hyprpaper
ec=$?
if [ "$ec" -eq 0 ]; then
  sudo systemctl --global disable hyprpaper.service
  ec=$?
fi
set -e
printf '\n'
if [ "$ec" -eq 0 ]; then
  printf '%s\n' "Wallpaper is installed. Press Super+Space and choose Wallpaper."
else
  printf 'Install failed (%s).\n' "$ec"
fi
read -r -p 'Press Enter to close. '
EOF
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
  setsid --fork -- hyprpaper --config "$cfg" </dev/null >/dev/null 2>&1
}

corebrum_wallpaper_menu_open() {
  local choice line label path
  if ! corebrum_wallpaper_menu_ready; then
    corebrum_wallpaper_menu_terminal "$(corebrum_wallpaper_menu_install_script)"
    return 0
  fi

  local -a rows=()
  while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    rows+=("$line")
  done < <(corebrum_wallpaper_menu_images)

  if [[ "${#rows[@]}" -eq 0 ]]; then
    if [[ "${COREBRUM_WALLPAPER_STUB:-0}" == 1 ]]; then
      printf '%s\n' "No wallpaper images found"
      return 0
    fi
    printf '%s\n' "No wallpaper images found" | fuzzel \
      --config /etc/corebrum/fuzzel/fuzzel.ini \
      --dmenu \
      --prompt 'Wallpaper  ' \
      --width 40 \
      --lines 1 >/dev/null || return 0
    return 0
  fi

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
