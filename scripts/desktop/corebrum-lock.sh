#!/usr/bin/env bash
# Lock the Sway session with gtklock 4. Ubuntu 24.04 builds that version.
# Ubuntu 26.04 uses the archive package. Keep the package case aligned with
# corebrum_lock_package in scripts/lib/preflight.sh.
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

corebrum_lock_main() {
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

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  corebrum_lock_main
fi
