#!/usr/bin/env bash
# Package manifest parser. Source this file; do not execute it.
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  echo "source scripts/lib/manifest.sh from another script" >&2
  exit 1
fi

corebrum_valid_package_name() {
  [[ "$1" =~ ^[a-z0-9][a-z0-9+.-]*$ ]]
}

# corebrum_load_manifest <file> <array-name>
corebrum_load_manifest() {
  local file="$1"
  local -n _corebrum_packages="$2"
  local line trimmed
  _corebrum_packages=()
  [[ -f "$file" ]] || corebrum_die "manifest not found: ${file}"
  while IFS= read -r line || [[ -n "$line" ]]; do
    trimmed="${line%%#*}"
    trimmed="${trimmed#"${trimmed%%[![:space:]]*}"}"
    trimmed="${trimmed%"${trimmed##*[![:space:]]}"}"
    [[ -z "$trimmed" ]] && continue
    if ! corebrum_valid_package_name "$trimmed"; then
      corebrum_die "invalid package name in ${file}: ${trimmed}"
    fi
    _corebrum_packages+=("$trimmed")
  done <"$file"
  if [[ "${#_corebrum_packages[@]}" -eq 0 ]]; then
    corebrum_die "manifest has no packages: ${file}"
  fi
}
