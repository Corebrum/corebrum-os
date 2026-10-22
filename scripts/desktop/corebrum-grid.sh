#!/usr/bin/env bash
# Show the Corebrum app grid. Tiles come from the dashboard manifest.
set -euo pipefail

corebrum_grid_lib() {
  local dir lib_parent
  if [[ -n "${COREBRUM_GRID_LIB:-}" ]]; then
    printf '%s\n' "$COREBRUM_GRID_LIB"
    return 0
  fi
  lib_parent="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib"
  dir=""
  if [[ -d "$lib_parent" ]]; then
    dir="$(cd "$lib_parent" && pwd)"
  fi
  if [[ -n "$dir" && -f "${dir}/grid.sh" ]]; then
    printf '%s\n' "${dir}/grid.sh"
    return 0
  fi
  if [[ -f /usr/local/lib/corebrum/grid.sh ]]; then
    printf '%s\n' /usr/local/lib/corebrum/grid.sh
    return 0
  fi
  echo "corebrum-grid: tile library not found" >&2
  return 1
}

# shellcheck source=../lib/grid.sh
source "$(corebrum_grid_lib)"

manifest="${COREBRUM_GRID_MANIFEST:-/etc/corebrum/dashboard/tiles.conf}"
labels=()
commands=()
corebrum_load_tiles "$manifest" labels commands

if [[ "${1:-}" == "--list" ]]; then
  printf '%s\n' "${labels[@]}"
  exit 0
fi

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  echo "Usage: corebrum-grid [--list]"
  exit 0
fi

if ! command -v wofi >/dev/null 2>&1; then
  echo "corebrum-grid: wofi is not installed" >&2
  exit 1
fi

cache="${XDG_RUNTIME_DIR:-/tmp}/corebrum-grid.cache"
selected=""
if ! selected="$(
  printf '%s\n' "${labels[@]}" | wofi \
    --dmenu \
    --conf /etc/corebrum/wofi/config \
    --style /etc/corebrum/wofi/style.css \
    --cache-file "$cache" \
    --prompt Corebrum
)"; then
  exit 0
fi
[[ -n "$selected" ]] || exit 0

index=0
choice=""
for label in "${labels[@]}"; do
  if [[ "$label" == "$selected" ]]; then
    choice="${commands[$index]}"
    break
  fi
  index=$((index + 1))
done
[[ -n "$choice" ]] || exit 0
exec bash -c "$choice"
