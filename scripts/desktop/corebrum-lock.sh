#!/usr/bin/env bash
# Lock the Sway session. Ubuntu 24.04 uses swaylock. Ubuntu 26.04 uses gtklock.
set -euo pipefail

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

# Keep this case aligned with corebrum_lock_package in scripts/lib/preflight.sh.
corebrum_lock_package() {
  case "$1" in
    noble) printf 'swaylock\n' ;;
    resolute) printf 'gtklock\n' ;;
    *) return 1 ;;
  esac
}

corebrum_lock_main() {
  local codename package here
  codename="$(corebrum_lock_codename)"
  package="$(corebrum_lock_package "$codename" || true)"
  if [[ -z "$package" ]] || ! command -v "$package" >/dev/null 2>&1; then
    printf 'corebrum-lock: %s is not installed\n' "${package:-a lock program}" >&2
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

  if [[ "$package" == "swaylock" ]]; then
    if [[ ! -f /etc/corebrum/sway/swaylock.conf ]]; then
      printf 'corebrum-lock: missing /etc/corebrum/sway/swaylock.conf\n' >&2
      exit 1
    fi
    exec swaylock --config /etc/corebrum/sway/swaylock.conf
  fi

  if [[ ! -f /etc/corebrum/gtklock/config.ini ]]; then
    printf 'corebrum-lock: missing /etc/corebrum/gtklock/config.ini\n' >&2
    exit 1
  fi
  exec gtklock --config /etc/corebrum/gtklock/config.ini
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  corebrum_lock_main
fi
