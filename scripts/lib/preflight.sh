#!/usr/bin/env bash
# Host checks for Ubuntu resolute on x86-64 or aarch64. Source this file; do not execute it.
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
  [[ "$1" == "resolute" ]]
}

corebrum_supported_arch() {
  [[ "$1" == "x86_64" || "$1" == "aarch64" ]]
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
  local codename version_id arch free_kib
  [[ -f "$os_release" ]] || corebrum_die "missing ${os_release}; Corebrum OS requires Ubuntu resolute"
  codename="$(corebrum_read_os_release_field "$os_release" VERSION_CODENAME || true)"
  [[ -n "$codename" ]] || corebrum_die "VERSION_CODENAME is missing from ${os_release}"
  if ! corebrum_supported_ubuntu "$codename"; then
    corebrum_die "Corebrum OS requires Ubuntu resolute (found VERSION_CODENAME=${codename})"
  fi
  version_id="$(corebrum_read_os_release_field "$os_release" VERSION_ID || true)"
  arch="$(uname -m)"
  if ! corebrum_supported_arch "$arch"; then
    corebrum_die "Corebrum OS supports x86_64 and aarch64 (found ${arch})"
  fi
  free_kib="$(corebrum_root_free_kib)"
  if ! corebrum_disk_is_sufficient "$free_kib" "$COREBRUM_MIN_FREE_KIB"; then
    corebrum_die "need at least ${COREBRUM_MIN_FREE_KIB} KiB free on / (have ${free_kib})"
  fi
  corebrum_log "preflight: Ubuntu ${codename} ${version_id:-unknown} ${arch}, ${free_kib} KiB free on /"
  if corebrum_can_reach_archive; then
    corebrum_log "preflight: archive.ubuntu.com:80 is reachable"
  else
    corebrum_die "cannot reach archive.ubuntu.com:80; check connectivity before installing"
  fi
}
