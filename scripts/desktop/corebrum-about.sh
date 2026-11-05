#!/usr/bin/env bash
# System About card. Prints hardware, software, and age/uptime/update.
# Super+Space opens this in a floating Kitty window. corebrum about prints
# the same card and exits.
set -euo pipefail

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

corebrum_about_heading() {
  local title="$1"
  local width=52
  local title_w left right
  title_w="$(printf '%s' "$title" | wc -L)"
  left=$(( (width - title_w + 1) / 2 ))
  right=$(( width - title_w - left ))
  (( left > 0 )) || left=1
  (( right > 0 )) || right=1
  printf '┌'
  printf '─%.0s' $(seq "$left")
  printf '%s' "$title"
  printf '─%.0s' $(seq "$right")
  printf '┐\n'
}

corebrum_about_footer() {
  printf '└────────────────────────────────────────────────────┘\n'
}

corebrum_about_row() {
  local key="$1"
  local value="$2"
  printf '%-12s %s\n' "$key" "$value"
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

corebrum_about_print() {
  local value synapse

  printf '\n'
  corebrum_about_banner
  printf '\n'
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
  printf '\n'

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
  printf '\n'

  corebrum_about_heading "Age / Uptime / Update"
  corebrum_about_row "OS Age" "$(corebrum_about_os_age)"
  corebrum_about_row "Uptime" "$(corebrum_about_uptime)"
  corebrum_about_row "Update" "$(corebrum_about_last_update)"
  corebrum_about_footer
  printf '\n'
}

corebrum_about_render() {
  printf '\e[?25l'
  corebrum_about_print
  printf 'Press any key to close.\n'
  # shellcheck disable=SC2162
  read -n 1 -s || true
  printf '\e[?25h'
}

corebrum_about_open() {
  local term about
  if [[ "${COREBRUM_ABOUT_STUB:-0}" == 1 ]]; then
    printf 'corebrum-terminal --class org.corebrum.about corebrum-about --render\n'
    return 0
  fi
  term="$(command -v corebrum-terminal 2>/dev/null || true)"
  about="$(command -v corebrum-about 2>/dev/null || true)"
  [[ -n "$term" ]] || corebrum_about_die "corebrum-terminal is not installed"
  [[ -n "$about" ]] || about="$0"
  exec "$term" --class org.corebrum.about "$about" --render
}

usage() {
  cat <<'EOF'
Usage: corebrum-about print|open|--render
EOF
}

cmd="${1:-print}"
case "$cmd" in
  print) corebrum_about_print ;;
  open) corebrum_about_open ;;
  --render | render) corebrum_about_render ;;
  -h | --help | help) usage ;;
  *)
    usage >&2
    exit 1
    ;;
esac
