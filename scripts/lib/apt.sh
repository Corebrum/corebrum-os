#!/usr/bin/env bash
# APT helpers. Source this file; do not execute it.
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  echo "source scripts/lib/apt.sh from another script" >&2
  exit 1
fi

corebrum_apt_install() {
  if [[ "$#" -eq 0 ]]; then
    corebrum_die "no packages to install"
  fi
  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    corebrum_log "dry-run: apt-get update"
    corebrum_log "dry-run: apt-get install -y $*"
    return 0
  fi
  export DEBIAN_FRONTEND=noninteractive
  corebrum_log "run: apt-get update"
  apt-get update
  corebrum_log "run: apt-get install -y $*"
  apt-get install -y "$@"
}
