#!/usr/bin/env bash
# System About card. Prints hardware, software, and age/uptime/update.
# Super+Space opens this in a floating Kitty window. corebrum about prints
# the same card and exits.
set -euo pipefail

# Box widths count characters, so make sure bash measures UTF-8, not bytes.
case "${LC_ALL:-${LC_CTYPE:-${LANG:-}}}" in
  *UTF-8* | *utf8*) ;;
  *) export LC_ALL=C.UTF-8 ;;
esac

corebrum_about_die() {
  printf 'corebrum-about: %s\n' "$1" >&2
  exit 1
}

corebrum_about_banner() {
  cat <<'EOF'
  ____   ___   ____   _____  ____   ____   _   _  __  __
 / ___| / _ \ |  _ \ | ____|| __ ) |  _ \ | | | ||  \/  |
| |    | | | || |_) ||  _|  |  _ \ | |_) || | | || |\/| |
| |___ | |_| ||  _ < | |___ | |_) ||  _ < | |_| || |  | |
 \____| \___/ |_| \_\|_____||____/ |_| \_\ \___/ |_|  |_|
EOF
}

# Each box is COREBRUM_ABOUT_BOX columns wide, borders included, so two boxes
# can sit side by side in the About window.
COREBRUM_ABOUT_BOX=58
COREBRUM_ABOUT_GAP=2

corebrum_about_repeat() {
  local n="$1"
  local ch="$2"
  local out=""
  while (( n-- > 0 )); do
    out+="$ch"
  done
  printf '%s' "$out"
}

corebrum_about_heading() {
  local title="$1"
  local width=$(( COREBRUM_ABOUT_BOX - 2 ))
  local left right
  left=$(( (width - ${#title} + 1) / 2 ))
  right=$(( width - ${#title} - left ))
  (( left > 0 )) || left=1
  (( right > 0 )) || right=1
  printf '┌%s%s%s┐\n' "$(corebrum_about_repeat "$left" '─')" "$title" "$(corebrum_about_repeat "$right" '─')"
}

corebrum_about_footer() {
  printf '└%s┘\n' "$(corebrum_about_repeat $(( COREBRUM_ABOUT_BOX - 2 )) '─')"
}

corebrum_about_row() {
  local key="$1"
  local value="$2"
  # Border, space, 12-column key, space, value, space, border.
  local room=$(( COREBRUM_ABOUT_BOX - 17 ))
  if (( ${#value} > room )); then
    value="${value:0:room-1}…"
  fi
  printf '│ %-12s %s%s │\n' "$key" "$value" "$(corebrum_about_repeat $(( room - ${#value} )) ' ')"
}

corebrum_about_corebrum_version() {
  local path version
  if [[ -n "${COREBRUM_ABOUT_VERSION:-}" ]]; then
    printf '%s\n' "$COREBRUM_ABOUT_VERSION"
    return 0
  fi
  if command -v corebrum >/dev/null 2>&1; then
    version="$(corebrum version 2>/dev/null | awk '{print $NF}' || true)"
    if [[ -n "$version" ]]; then
      printf '%s\n' "$version"
      return 0
    fi
  fi
  path="$(command -v corebrum 2>/dev/null || true)"
  if [[ -L "$path" ]]; then
    path="$(readlink -f "$path")"
    path="$(cd "$(dirname "$path")/.." && pwd)/VERSION"
    if [[ -f "$path" ]]; then
      tr -d '[:space:]' <"$path"
      return 0
    fi
  fi
  printf 'unknown\n'
}

corebrum_about_synapse_version() {
  local version
  if [[ -n "${COREBRUM_ABOUT_SYNAPSE:-}" ]]; then
    printf '%s\n' "$COREBRUM_ABOUT_SYNAPSE"
    return 0
  fi
  if ! command -v synapse >/dev/null 2>&1; then
    printf 'not installed\n'
    return 0
  fi
  version="$(synapse --version 2>/dev/null | head -n 1 | tr -d '[:space:]' || true)"
  if [[ -z "$version" ]]; then
    printf 'not installed\n'
    return 0
  fi
  printf '%s\n' "$version"
}

corebrum_about_pc() {
  local model vendor hostname
  if [[ -n "${COREBRUM_ABOUT_PC:-}" ]]; then
    printf '%s\n' "$COREBRUM_ABOUT_PC"
    return 0
  fi
  model="$(hostnamectl 2>/dev/null | awk -F': ' '/Hardware Model:/ {print $2; exit}')"
  vendor="$(hostnamectl 2>/dev/null | awk -F': ' '/Hardware Vendor:/ {print $2; exit}')"
  if [[ -n "$model" && -n "$vendor" && "$model" != "$vendor"* ]]; then
    printf '%s %s\n' "$vendor" "$model"
    return 0
  fi
  if [[ -n "$model" ]]; then
    printf '%s\n' "$model"
    return 0
  fi
  hostname="$(hostname 2>/dev/null || true)"
  printf '%s\n' "${hostname:-unknown}"
}

corebrum_about_cpu() {
  local name count
  if [[ -n "${COREBRUM_ABOUT_CPU:-}" ]]; then
    printf '%s\n' "$COREBRUM_ABOUT_CPU"
    return 0
  fi
  name="$(lscpu 2>/dev/null | awk -F': *' '/^Model name:/ {print $2; exit}')"
  if [[ -z "$name" || "$name" == "-" ]]; then
    name="$(awk -F': *' '/^model name/ {print $2; exit}' /proc/cpuinfo 2>/dev/null || true)"
  fi
  if [[ -z "$name" || "$name" == "-" ]]; then
    name="$(awk -F': *' '/^Hardware/ {print $2; exit}' /proc/cpuinfo 2>/dev/null || true)"
  fi
  # Jetson and some ARM boards leave Model name blank; Vendor ID still names the ISA.
  if [[ -z "$name" || "$name" == "-" ]]; then
    name="$(lscpu 2>/dev/null | awk -F': *' '/^Vendor ID:/ {print $2; exit}')"
  fi
  count="$(nproc 2>/dev/null || true)"
  if [[ -n "$name" && -n "$count" ]]; then
    printf '%s (%s)\n' "$name" "$count"
    return 0
  fi
  if [[ -n "$count" ]]; then
    printf 'CPU (%s)\n' "$count"
    return 0
  fi
  printf '%s\n' "${name:-unknown}"
}

corebrum_about_gpu() {
  local line
  if [[ -n "${COREBRUM_ABOUT_GPU:-}" ]]; then
    printf '%s\n' "$COREBRUM_ABOUT_GPU"
    return 0
  fi
  if command -v lspci >/dev/null 2>&1; then
    line="$(lspci 2>/dev/null | awk -F': ' '/VGA compatible controller|3D controller|Display controller/ {print $2; exit}')"
    if [[ -n "$line" ]]; then
      printf '%s\n' "$line"
      return 0
    fi
  fi
  printf 'unknown\n'
}

corebrum_about_display() {
  local outs
  if [[ -n "${COREBRUM_ABOUT_DISPLAY:-}" ]]; then
    printf '%s\n' "$COREBRUM_ABOUT_DISPLAY"
    return 0
  fi
  if [[ -z "${SWAYSOCK:-}" ]] || ! command -v swaymsg >/dev/null 2>&1; then
    return 1
  fi
  outs="$(swaymsg -t get_outputs 2>/dev/null | awk '
    /^Output / { name=$2 }
    /Current mode:/ {
      mode=$3
      if (name != "" && mode != "") {
        if (out != "") out=out ", "
        out=out name " " mode
      }
    }
    END { if (out != "") print out }
  ')"
  [[ -n "$outs" ]] || return 1
  printf '%s\n' "$outs"
}

corebrum_about_disk() {
  local used size pct
  if [[ -n "${COREBRUM_ABOUT_DISK:-}" ]]; then
    printf '%s\n' "$COREBRUM_ABOUT_DISK"
    return 0
  fi
  read -r size used pct < <(df -h / 2>/dev/null | awk 'NR==2 {print $2, $3, $5}')
  if [[ -z "${size:-}" ]]; then
    printf 'unknown\n'
    return 0
  fi
  printf '%s / %s (%s)\n' "$used" "$size" "$pct"
}

corebrum_about_memory() {
  local used total
  if [[ -n "${COREBRUM_ABOUT_MEMORY:-}" ]]; then
    printf '%s\n' "$COREBRUM_ABOUT_MEMORY"
    return 0
  fi
  read -r total used < <(free -h 2>/dev/null | awk '/^Mem:/ {print $2, $3}')
  if [[ -z "${total:-}" ]]; then
    printf 'unknown\n'
    return 0
  fi
  printf '%s / %s\n' "$used" "$total"
}

corebrum_about_swap() {
  local used total
  if [[ -n "${COREBRUM_ABOUT_SWAP:-}" ]]; then
    [[ "$COREBRUM_ABOUT_SWAP" == "none" ]] && return 1
    printf '%s\n' "$COREBRUM_ABOUT_SWAP"
    return 0
  fi
  read -r total used < <(free -h 2>/dev/null | awk '/^Swap:/ {print $2, $3}')
  if [[ -z "${total:-}" || "$total" == "0B" || "$total" == "0" ]]; then
    return 1
  fi
  printf '%s / %s\n' "$used" "$total"
}

corebrum_about_os() {
  if [[ -n "${COREBRUM_ABOUT_OS:-}" ]]; then
    printf '%s\n' "$COREBRUM_ABOUT_OS"
    return 0
  fi
  # shellcheck disable=SC1091
  . /etc/os-release 2>/dev/null || true
  printf '%s\n' "${PRETTY_NAME:-unknown}"
}

corebrum_about_kernel() {
  if [[ -n "${COREBRUM_ABOUT_KERNEL:-}" ]]; then
    printf '%s\n' "$COREBRUM_ABOUT_KERNEL"
    return 0
  fi
  uname -r
}

corebrum_about_wm() {
  if [[ -n "${COREBRUM_ABOUT_WM:-}" ]]; then
    printf '%s\n' "$COREBRUM_ABOUT_WM"
    return 0
  fi
  if [[ -n "${SWAYSOCK:-}" ]]; then
    printf 'Sway\n'
    return 0
  fi
  printf '%s\n' "${XDG_CURRENT_DESKTOP:-unknown}"
}

corebrum_about_terminal() {
  if [[ -n "${COREBRUM_ABOUT_TERMINAL:-}" ]]; then
    printf '%s\n' "$COREBRUM_ABOUT_TERMINAL"
    return 0
  fi
  printf 'Kitty\n'
}

corebrum_about_os_age() {
  local birth now days
  if [[ -n "${COREBRUM_ABOUT_OS_AGE:-}" ]]; then
    printf '%s\n' "$COREBRUM_ABOUT_OS_AGE"
    return 0
  fi
  birth="$(stat -c %W /var/log 2>/dev/null || printf '0')"
  if [[ -z "$birth" || "$birth" == "0" || "$birth" == "-" ]]; then
    printf 'unknown\n'
    return 0
  fi
  now="$(date +%s)"
  days=$(( (now - birth) / 86400 ))
  if (( days == 1 )); then
    printf '1 day\n'
  else
    printf '%s days\n' "$days"
  fi
}

corebrum_about_uptime() {
  local up d h m
  if [[ -n "${COREBRUM_ABOUT_UPTIME:-}" ]]; then
    printf '%s\n' "$COREBRUM_ABOUT_UPTIME"
    return 0
  fi
  if command -v uptime >/dev/null 2>&1 && uptime -p >/dev/null 2>&1; then
    uptime -p | sed 's/^up //'
    return 0
  fi
  up="$(cut -d. -f1 /proc/uptime 2>/dev/null || printf '0')"
  d=$((up / 86400))
  h=$((up % 86400 / 3600))
  m=$((up % 3600 / 60))
  if (( d > 0 )); then
    printf '%s days, %s hours, %s minutes\n' "$d" "$h" "$m"
  elif (( h > 0 )); then
    printf '%s hours, %s minutes\n' "$h" "$m"
  else
    printf '%s minutes\n' "$m"
  fi
}

corebrum_about_last_update() {
  local log stamp
  if [[ -n "${COREBRUM_ABOUT_UPDATE:-}" ]]; then
    printf '%s\n' "$COREBRUM_ABOUT_UPDATE"
    return 0
  fi
  log="${COREBRUM_ABOUT_APT_HISTORY:-/var/log/apt/history.log}"
  if [[ ! -f "$log" ]]; then
    printf 'unknown\n'
    return 0
  fi
  stamp="$(awk '
    /^Start-Date:/ {
      stamp=$0
      sub(/^Start-Date:[[:space:]]*/, "", stamp)
    }
    /^Commandline:/ && $0 ~ /(^|[[:space:]])(full-)?upgrade([[:space:]]|$)/ {
      last=stamp
    }
    END {
      if (last != "") print last
    }
  ' "$log")"
  printf '%s\n' "${stamp:-unknown}"
}

corebrum_about_hardware() {
  local value
  corebrum_about_heading "Hardware"
  corebrum_about_row "PC" "$(corebrum_about_pc)"
  corebrum_about_row "CPU" "$(corebrum_about_cpu)"
  corebrum_about_row "GPU" "$(corebrum_about_gpu)"
  if value="$(corebrum_about_display)"; then
    corebrum_about_row "Display" "$value"
  fi
  corebrum_about_row "Disk" "$(corebrum_about_disk)"
  corebrum_about_row "Memory" "$(corebrum_about_memory)"
  if value="$(corebrum_about_swap)"; then
    corebrum_about_row "Swap" "$value"
  fi
  corebrum_about_footer
}

corebrum_about_software() {
  local synapse
  corebrum_about_heading "Software"
  corebrum_about_row "Corebrum" "Corebrum $(corebrum_about_corebrum_version)"
  synapse="$(corebrum_about_synapse_version)"
  if [[ "$synapse" == "not installed" ]]; then
    corebrum_about_row "Synapse" "not installed"
  else
    corebrum_about_row "Synapse" "Corebrum Synapse ${synapse}"
  fi
  corebrum_about_row "OS" "$(corebrum_about_os)"
  corebrum_about_row "Kernel" "$(corebrum_about_kernel)"
  corebrum_about_row "WM" "$(corebrum_about_wm)"
  corebrum_about_row "Terminal" "$(corebrum_about_terminal)"
  corebrum_about_footer
}

corebrum_about_age() {
  corebrum_about_heading "Age / Uptime / Update"
  corebrum_about_row "OS Age" "$(corebrum_about_os_age)"
  corebrum_about_row "Uptime" "$(corebrum_about_uptime)"
  corebrum_about_row "Update" "$(corebrum_about_last_update)"
  corebrum_about_footer
}

# One column: Hardware, Software, then Age stacked. corebrum about uses this.
corebrum_about_print() {
  printf '\n'
  corebrum_about_banner
  printf '\n'
  corebrum_about_hardware
  printf '\n'
  corebrum_about_software
  printf '\n'
  corebrum_about_age
  printf '\n'
}

# Two columns: Hardware beside Software, then Age centered under both. The About
# window is sized for this so the card fits without scrolling.
corebrum_about_print_columns() {
  local -a left right
  local i n gap blank indent
  mapfile -t left < <(corebrum_about_hardware)
  mapfile -t right < <(corebrum_about_software)
  n=${#left[@]}
  (( ${#right[@]} > n )) && n=${#right[@]}
  gap="$(corebrum_about_repeat "$COREBRUM_ABOUT_GAP" ' ')"
  blank="$(corebrum_about_repeat "$COREBRUM_ABOUT_BOX" ' ')"
  # Center the 57-column banner and the Age box over both columns.
  indent="$(corebrum_about_repeat $(( COREBRUM_ABOUT_BOX + COREBRUM_ABOUT_GAP / 2 - 28 )) ' ')"
  printf '\n'
  corebrum_about_banner | sed "s/^/${indent}/"
  printf '\n'
  for (( i = 0; i < n; i++ )); do
    if [[ -n "${right[i]:-}" ]]; then
      printf '%s%s%s\n' "${left[i]:-$blank}" "$gap" "${right[i]}"
    else
      printf '%s\n' "${left[i]:-}"
    fi
  done
  printf '\n'
  corebrum_about_age | sed "s/^/$(corebrum_about_repeat $(( (COREBRUM_ABOUT_BOX + COREBRUM_ABOUT_GAP) / 2 )) ' ')/"
  printf '\n'
}

corebrum_about_columns_fit() {
  local cols
  cols="$(tput cols 2>/dev/null || printf '%s' "${COLUMNS:-0}")"
  (( cols >= COREBRUM_ABOUT_BOX * 2 + COREBRUM_ABOUT_GAP ))
}

corebrum_about_rows() {
  tput lines 2>/dev/null || printf '%s' "${LINES:-0}"
}

# The About window. Kitty opens it at the two-column size. A smaller window
# gets one column, and a window too short for that drops the banner, so the
# card does not scroll. A resize redraws without re-reading the machine.
# Bash restarts read after SIGWINCH, so the size is polled instead.
corebrum_about_render() {
  local wide narrow bare fit last="" card rows
  wide="$(corebrum_about_print_columns)"
  narrow="$(corebrum_about_print)"
  # The one-column card without the banner and the blank rows around it.
  bare="$(sed '1,7d' <<<"$narrow")"
  printf '\e[?25l'
  while true; do
    rows="$(corebrum_about_rows)"
    if corebrum_about_columns_fit; then
      card="$wide"
    else
      card="$narrow"
      if (( $(wc -l <<<"$narrow") + 2 > rows )); then
        card="$bare"
      fi
    fi
    fit="$(tput cols 2>/dev/null)x${rows}"
    if [[ "$fit" != "$last" ]]; then
      printf '\e[H\e[2J%s\n\n' "$card"
      printf 'Press any key to close.'
      last="$fit"
    fi
    # A timeout returns above 128. Any key or end of input closes the card.
    # shellcheck disable=SC2162
    read -n 1 -s -t 0.3 && break
    (( $? > 128 )) || break
  done
  printf '\e[?25h'
}

# Kitty sizes the window in cells, so the two-column card fits whatever the
# font measures. Kitty otherwise reopens at the last size it saved, and Sway
# keeps a floating window at the size the client asks for.
corebrum_about_kitty_size() {
  printf -- '-o remember_window_size=no -o initial_window_width=%sc -o initial_window_height=%sc\n' \
    $(( COREBRUM_ABOUT_BOX * 2 + COREBRUM_ABOUT_GAP + 2 )) 26
}

corebrum_about_open() {
  local term about
  if [[ "${COREBRUM_ABOUT_STUB:-0}" == 1 ]]; then
    printf 'corebrum-terminal --class org.corebrum.about %s corebrum-about --render\n' "$(corebrum_about_kitty_size)"
    return 0
  fi
  term="$(command -v corebrum-terminal 2>/dev/null || true)"
  about="$(command -v corebrum-about 2>/dev/null || true)"
  [[ -n "$term" ]] || corebrum_about_die "corebrum-terminal is not installed"
  [[ -n "$about" ]] || about="$0"
  # shellcheck disable=SC2046
  exec "$term" --class org.corebrum.about $(corebrum_about_kitty_size) "$about" --render
}

usage() {
  cat <<'EOF'
Usage: corebrum-about print|columns|open|--render
EOF
}

cmd="${1:-print}"
case "$cmd" in
  print) corebrum_about_print ;;
  columns) corebrum_about_print_columns ;;
  open) corebrum_about_open ;;
  --render | render) corebrum_about_render ;;
  -h | --help | help) usage ;;
  *)
    usage >&2
    exit 1
    ;;
esac
