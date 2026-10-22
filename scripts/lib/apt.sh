#!/usr/bin/env bash
# APT helpers. Source this file; do not execute it.
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  echo "source scripts/lib/apt.sh from another script" >&2
  exit 1
fi

corebrum_apt_install() {
  local -a extra=()
  if [[ "${1:-}" == "--no-install-recommends" ]]; then
    extra+=(--no-install-recommends)
    shift
  fi
  if [[ "$#" -eq 0 ]]; then
    corebrum_die "no packages to install"
  fi
  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    corebrum_log "dry-run: apt-get update"
    if [[ "${#extra[@]}" -eq 0 ]]; then
      corebrum_log "dry-run: apt-get install -y $*"
    else
      corebrum_log "dry-run: apt-get install -y ${extra[*]} $*"
    fi
    return 0
  fi
  export DEBIAN_FRONTEND=noninteractive
  corebrum_log "run: apt-get update"
  apt-get update
  if [[ "${#extra[@]}" -eq 0 ]]; then
    corebrum_log "run: apt-get install -y $*"
    apt-get install -y "$@"
  else
    corebrum_log "run: apt-get install -y ${extra[*]} $*"
    apt-get install -y "${extra[@]}" "$@"
  fi
}
