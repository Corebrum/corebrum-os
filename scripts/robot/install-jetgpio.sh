#!/usr/bin/env bash
# Optional JETGPIO installer helper. Not run automatically by corebrum install.
set -euo pipefail

DRY_RUN="${DRY_RUN:-0}"
JETGPIO_REPO="${JETGPIO_REPO:-https://github.com/Rubberazer/JETGPIO.git}"
JETGPIO_REF="${JETGPIO_REF:-v1.2}"
DESTDIR="${DESTDIR:-/usr/local/lib}"

usage() {
  cat <<'EOF'
Usage: install-jetgpio.sh [--dry-run]

Clones JETGPIO, builds, and installs libjetgpio.so (requires root without --dry-run).
Set JETGPIO_REPO or JETGPIO_REF to override upstream.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      echo "unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ "$DRY_RUN" -eq 0 && "$(id -u)" -ne 0 ]]; then
  echo "run as root or pass --dry-run" >&2
  exit 1
fi

build_dir="$(mktemp -d)"
trap 'rm -rf "$build_dir"' EXIT

if [[ "$DRY_RUN" -eq 1 ]]; then
  printf 'would clone %s at %s into %s\n' "$JETGPIO_REPO" "$JETGPIO_REF" "$build_dir"
  printf 'would run make && make install (DESTDIR=%s)\n' "$DESTDIR"
  exit 0
fi

git clone --depth 1 --branch "$JETGPIO_REF" "$JETGPIO_REPO" "$build_dir/JETGPIO"
cd "$build_dir/JETGPIO"
make
make install DESTDIR="$DESTDIR"
printf 'installed libjetgpio under %s\n' "$DESTDIR"