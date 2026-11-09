#!/usr/bin/env bash
# Lock the Sway session with gtklock 4. Ubuntu 24.04 builds that version.
# Ubuntu 26.04 uses the archive package. Keep the package case aligned with
# corebrum_lock_package in scripts/lib/preflight.sh.
set -euo pipefail

COREBRUM_LOCK_STATE="${XDG_STATE_HOME:-${HOME}/.local/state}/corebrum"
COREBRUM_LOCK_PENDING_AUTOLOCK="${COREBRUM_LOCK_STATE}/pending-autolock"
COREBRUM_LOCK_DIMMED_MARK="${COREBRUM_LOCK_STATE}/display-dimmed"

corebrum_lock_codename() {
  local codename
  if [[ -n "${COREBRUM_LOCK_CODENAME:-}" ]]; then
    printf '%s\n' "$COREBRUM_LOCK_CODENAME"
    return 0
  fi
  # shellcheck disable=SC1091
  codename="$(. /etc/os-release && printf '%s' "${VERSION_CODENAME:-}")"
  printf '%s\n' "$codename"
}

corebrum_lock_package() {
  case "$1" in
    noble|resolute) printf 'gtklock\n' ;;
    *) return 1 ;;
  esac
}

corebrum_lock_bin() {
  local bin version
  for bin in /usr/local/bin/gtklock /usr/bin/gtklock; do
    [[ -x "$bin" ]] || continue
    version="$("$bin" -v 2>/dev/null || true)"
    if [[ "$version" == gtklock\ v4.* ]]; then
      printf '%s\n' "$bin"
      return 0
    fi
  done
  return 1
}

corebrum_lock_wake_display() {
  local dim_cmd
  dim_cmd="$(command -v corebrum-display-dim 2>/dev/null || true)"
  if [[ -z "$dim_cmd" && -x /usr/local/bin/corebrum-display-dim ]]; then
    dim_cmd=/usr/local/bin/corebrum-display-dim
  fi
  if [[ -n "$dim_cmd" ]]; then
    COREBRUM_DISPLAY_DIM_SKIP_PENDING_AUTOLOCK=1 "$dim_cmd" on || true
  fi
}

corebrum_lock_clear_pending() {
  rm -f "$COREBRUM_LOCK_PENDING_AUTOLOCK"
}

corebrum_lock_display_dimmed() {
  if [[ "${COREBRUM_LOCK_DIMMED_STUB:-0}" == 1 ]]; then
    return 0
  fi
  [[ -f "$COREBRUM_LOCK_DIMMED_MARK" ]]
}

corebrum_lock_run_gtklock() {
  if [[ "${COREBRUM_LOCK_GTKLOCK_STUB:-0}" == 1 ]]; then
    printf 'gtklock\n'
    return 0
  fi
  local codename package bin here
  codename="$(corebrum_lock_codename)"
  package="$(corebrum_lock_package "$codename" || true)"
  bin="$(corebrum_lock_bin || true)"
  if [[ "$package" != "gtklock" || -z "$bin" ]]; then
    printf 'corebrum-lock: gtklock 4 is not installed\n' >&2
    exit 1
  fi

  here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  if [[ -f "${here}/corebrum-drm.sh" ]]; then
    # shellcheck source=corebrum-drm.sh
    source "${here}/corebrum-drm.sh"
  elif [[ -f /usr/local/lib/corebrum/drm.sh ]]; then
    # shellcheck source=corebrum-drm.sh
    source /usr/local/lib/corebrum/drm.sh
  fi
  if declare -F corebrum_export_vc4_devices >/dev/null 2>&1; then
    corebrum_export_vc4_devices
  fi

  if [[ ! -f /etc/corebrum/gtklock/config.ini ]]; then
    printf 'corebrum-lock: missing /etc/corebrum/gtklock/config.ini\n' >&2
    exit 1
  fi
  exec "$bin" --config /etc/corebrum/gtklock/config.ini
}

corebrum_lock_idle() {
  if [[ "${COREBRUM_LOCK_IDLE_STUB:-0}" == 1 ]]; then
    if corebrum_lock_display_dimmed; then
      mkdir -p "$COREBRUM_LOCK_STATE"
      touch "$COREBRUM_LOCK_PENDING_AUTOLOCK"
      printf 'idle defer\n'
      return 0
    fi
    printf 'idle lock\n'
    return 0
  fi
  if corebrum_lock_display_dimmed; then
    mkdir -p "$COREBRUM_LOCK_STATE"
    touch "$COREBRUM_LOCK_PENDING_AUTOLOCK"
    return 0
  fi
  corebrum_lock_run_gtklock
}

corebrum_lock_main() {
  if [[ "${COREBRUM_LOCK_SKIP_WAKE:-0}" != 1 ]]; then
    corebrum_lock_clear_pending
    corebrum_lock_wake_display
  fi
  corebrum_lock_run_gtklock
}

usage() {
  cat <<'EOF'
Usage: corebrum-lock [idle]
EOF
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  cmd="${1:-}"
  case "$cmd" in
    idle) corebrum_lock_idle ;;
    -h | --help | help) usage ;;
    '' | lock) corebrum_lock_main ;;
    *)
      usage >&2
      exit 1
      ;;
  esac
fi
