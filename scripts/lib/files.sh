#!/usr/bin/env bash
# Install files Corebrum owns. Source this file; do not execute it.
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  echo "source scripts/lib/files.sh from another script" >&2
  exit 1
fi

COREBRUM_STATE_FILE="/etc/corebrum/desktop.state"

# corebrum_install_file <src> <dest> <mode>
# Copies src to dest. An existing different file is backed up first.
# Sets COREBRUM_LAST_BACKUP when a backup was made during this call.
corebrum_install_file() {
  local src="$1"
  local dest="$2"
  local mode="$3"
  COREBRUM_LAST_BACKUP=""
  export COREBRUM_LAST_BACKUP
  [[ -f "$src" ]] || corebrum_die "missing source file: ${src}"
  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    corebrum_log "dry-run: install ${dest}"
    return 0
  fi
  mkdir -p "$(dirname "$dest")"
  if [[ -f "$dest" ]] && cmp -s "$src" "$dest"; then
    corebrum_log "unchanged: ${dest}"
    return 0
  fi
  if [[ -e "$dest" ]]; then
    corebrum_backup_file "$dest"
  fi
  install -m "$mode" "$src" "$dest"
  corebrum_log "installed ${dest}"
}

corebrum_state_get() {
  local key="$1"
  local line
  [[ -f "$COREBRUM_STATE_FILE" ]] || return 1
  line="$(grep -E "^${key}=" "$COREBRUM_STATE_FILE" | tail -n 1 || true)"
  [[ -n "$line" ]] || return 1
  printf '%s' "${line#*=}"
}

# Record key=value only when that key is not already present.
corebrum_state_set_once() {
  local key="$1"
  local value="$2"
  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    corebrum_log "dry-run: record ${key} in ${COREBRUM_STATE_FILE} when unset"
    return 0
  fi
  mkdir -p "$(dirname "$COREBRUM_STATE_FILE")"
  if [[ -f "$COREBRUM_STATE_FILE" ]] && grep -qE "^${key}=" "$COREBRUM_STATE_FILE"; then
    corebrum_log "keeping recorded ${key}"
    return 0
  fi
  printf '%s=%s\n' "$key" "$value" >>"$COREBRUM_STATE_FILE"
  corebrum_log "recorded ${key}"
}
