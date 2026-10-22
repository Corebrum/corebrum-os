#!/usr/bin/env bash
# App-grid tile manifest. Source this file; do not execute it.
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  echo "source scripts/lib/grid.sh from another script" >&2
  exit 1
fi

if ! declare -F corebrum_die >/dev/null 2>&1; then
  corebrum_die() {
    echo "corebrum-grid: $*" >&2
    exit 1
  }
fi

corebrum_trim() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

# corebrum_load_tiles <file> <label-array> <command-array>
# Lines are "Label|command". Blank lines and # comments are ignored.
corebrum_load_tiles() {
  local file="$1"
  local -n _tile_labels="$2"
  local -n _tile_commands="$3"
  local line trimmed label command
  _tile_labels=()
  _tile_commands=()
  [[ -f "$file" ]] || corebrum_die "tile manifest not found: ${file}"
  while IFS= read -r line || [[ -n "$line" ]]; do
    trimmed="${line%%#*}"
    trimmed="$(corebrum_trim "$trimmed")"
    [[ -z "$trimmed" ]] && continue
    if [[ "$trimmed" != *"|"* ]]; then
      corebrum_die "invalid tile in ${file}: ${trimmed}"
    fi
    label="$(corebrum_trim "${trimmed%%|*}")"
    command="$(corebrum_trim "${trimmed#*|}")"
    if [[ -z "$label" || -z "$command" ]]; then
      corebrum_die "invalid tile in ${file}: ${trimmed}"
    fi
    _tile_labels+=("$label")
    _tile_commands+=("$command")
  done <"$file"
  if [[ "${#_tile_labels[@]}" -eq 0 ]]; then
    corebrum_die "tile manifest has no tiles: ${file}"
  fi
}
