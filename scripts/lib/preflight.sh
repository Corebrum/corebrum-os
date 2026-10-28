#!/usr/bin/env bash
# Host checks for Ubuntu 24.04 or 26.04 on x86-64 or aarch64. Source this file; do not execute it.
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
  [[ "$1" == "noble" || "$1" == "resolute" ]]
}

# ID, codename, and VERSION_ID have to name the same Ubuntu Server release.
corebrum_supported_release() {
  local id="$1" codename="$2" version_id="$3"
  [[ "$id" == "ubuntu" ]] || return 1
  case "$codename" in
    noble) [[ "$version_id" == "24.04" ]] ;;
    resolute) [[ "$version_id" == "26.04" ]] ;;
    *) return 1 ;;
  esac
}

# Both releases lock with gtklock 4. Noble builds it. Resolute uses the archive package.
corebrum_lock_package() {
  case "$1" in
    noble|resolute) printf 'gtklock\n' ;;
    *) return 1 ;;
  esac
}

# Noble's archive gtklock is 2.1 and cannot lock Sway 1.9.
corebrum_gtklock_from_source() {
  [[ "$1" == "noble" ]]
}

corebrum_gtklock_v4_path() {
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
  local id codename version_id arch free_kib
  [[ -f "$os_release" ]] || corebrum_die "missing ${os_release}; Corebrum OS requires Ubuntu 24.04 or 26.04"
  id="$(corebrum_read_os_release_field "$os_release" ID || true)"
  codename="$(corebrum_read_os_release_field "$os_release" VERSION_CODENAME || true)"
  version_id="$(corebrum_read_os_release_field "$os_release" VERSION_ID || true)"
  [[ -n "$codename" ]] || corebrum_die "VERSION_CODENAME is missing from ${os_release}"
  if ! corebrum_supported_release "$id" "$codename" "$version_id"; then
    corebrum_die "Corebrum OS requires Ubuntu 24.04 (noble) or 26.04 (resolute) (found ID=${id:-missing} VERSION_ID=${version_id:-missing} VERSION_CODENAME=${codename})"
  fi
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
