#!/usr/bin/env bash
# Shared log helpers. Source this file; do not execute it.
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  echo "source scripts/lib/log.sh from another script" >&2
  exit 1
fi

corebrum_log() {
  local msg
  msg="[corebrum] $(date -Is) $*"
  printf '%s\n' "$msg" >&2
  if [[ "${DRY_RUN:-0}" -eq 0 && -n "${COREBRUM_LOG_FILE:-}" ]]; then
    printf '%s\n' "$msg" >>"${COREBRUM_LOG_FILE}"
  fi
}

corebrum_die() {
  corebrum_log "ERROR: $*"
  exit 1
}

corebrum_init_log() {
  local stamp
  stamp="$(date +%Y%m%d-%H%M%S)"
  mkdir -p /var/log/corebrum
  COREBRUM_LOG_FILE="/var/log/corebrum/install-${stamp}.log"
  export COREBRUM_LOG_FILE
  ln -sfn "${COREBRUM_LOG_FILE}" /var/log/corebrum/install-latest.log
  corebrum_log "logging to ${COREBRUM_LOG_FILE}"
}
