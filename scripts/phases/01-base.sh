#!/usr/bin/env bash
# Phase 1 base profile. Sourced by scripts/install.sh.
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  echo "Run ./scripts/install.sh --profile base" >&2
  exit 1
fi

corebrum_phase_base() {
  local manifest="${COREBRUM_ROOT}/manifests/packages/base.txt"
  local -a packages=()
  corebrum_load_manifest "$manifest" packages
  if [[ "${ENABLE_SSH:-0}" -eq 1 ]]; then
    packages+=(openssh-server)
    corebrum_log "OpenSSH requested"
  else
    corebrum_log "OpenSSH not requested"
  fi
  corebrum_apt_install "${packages[@]}"
  corebrum_ensure_locale
  corebrum_ensure_ntp
  if [[ "${ENABLE_SSH:-0}" -eq 1 ]]; then
    corebrum_enable_ssh
  fi
  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    corebrum_log "base profile dry-run complete"
  else
    corebrum_log "base profile install complete"
  fi
}
