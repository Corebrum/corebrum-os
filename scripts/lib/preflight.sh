#!/usr/bin/env bash
# Host checks for Ubuntu Server 24.04 x86-64. Source this file; do not execute it.
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  echo "source scripts/lib/preflight.sh from another script" >&2
  exit 1
fi

COREBRUM_MIN_FREE_KIB=8388608

corebrum_read_os_release_field() {
  local file="$1"
  local field="$2"
  local line value
  line="$(grep -E "^${field}=" "$file" | tail -n 1 || true)"
  [[ -n "$line" ]] || return 1
  value="${line#*=}"
  value="${value%$'\r'}"
  if [[ "$value" == \"*\" || "$value" == \'*\' ]]; then
    value="${value:1:${#value}-2}"
  fi
  printf '%s' "$value"
}

corebrum_supported_ubuntu() {
  [[ "$1" == "24.04" ]]
}

corebrum_supported_arch() {
  [[ "$1" == "x86_64" ]]
}

corebrum_disk_is_sufficient() {
  local avail_kib="$1"
  local min_kib="$2"
  [[ "$avail_kib" -ge "$min_kib" ]]
}

corebrum_root_free_kib() {
  df -Pk / | awk 'NR==2 {print $4}'
}

corebrum_can_reach_archive() {
  timeout 10 bash -c 'exec 3<>/dev/tcp/archive.ubuntu.com/80' 2>/dev/null
}

corebrum_preflight() {
  local os_release="/etc/os-release"
  local version_id arch free_kib
  [[ -f "$os_release" ]] || corebrum_die "missing ${os_release}; Corebrum OS requires Ubuntu 24.04"
  version_id="$(corebrum_read_os_release_field "$os_release" VERSION_ID || true)"
  [[ -n "$version_id" ]] || corebrum_die "VERSION_ID is missing from ${os_release}"
  if ! corebrum_supported_ubuntu "$version_id"; then
    corebrum_die "Corebrum OS requires Ubuntu 24.04 (found VERSION_ID=${version_id})"
  fi
  arch="$(uname -m)"
  if ! corebrum_supported_arch "$arch"; then
    corebrum_die "Corebrum OS currently supports x86_64 only (found ${arch})"
  fi
  free_kib="$(corebrum_root_free_kib)"
  if ! corebrum_disk_is_sufficient "$free_kib" "$COREBRUM_MIN_FREE_KIB"; then
    corebrum_die "need at least ${COREBRUM_MIN_FREE_KIB} KiB free on / (have ${free_kib})"
  fi
  corebrum_log "preflight: Ubuntu ${version_id} ${arch}, ${free_kib} KiB free on /"
  if corebrum_can_reach_archive; then
    corebrum_log "preflight: archive.ubuntu.com:80 is reachable"
  else
    corebrum_die "cannot reach archive.ubuntu.com:80; check connectivity before installing"
  fi
}
