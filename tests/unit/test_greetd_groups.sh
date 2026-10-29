#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export COREBRUM_ROOT="$ROOT"
# shellcheck source=../../scripts/lib/log.sh
source "${ROOT}/scripts/lib/log.sh"
# shellcheck source=../../scripts/lib/desktop.sh
source "${ROOT}/scripts/lib/desktop.sh"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
DRY_RUN=0
ID_PRESENT=1
ID_GROUPS="_greetd"
export DRY_RUN
mkdir -p "${tmp}/groups"
touch "${tmp}/groups/video" "${tmp}/groups/render"
: >"${tmp}/usermod.log"

id() {
  if [[ "${1:-}" == "-nG" ]]; then
    printf '%s\n' "$ID_GROUPS"
    return 0
  fi
  [[ "$ID_PRESENT" -eq 1 ]]
}

getent() {
  [[ "${1:-}" == "group" && -e "${tmp}/groups/${2:-}" ]]
}

usermod() {
  printf '%s\n' "$*" >>"${tmp}/usermod.log"
}

ID_PRESENT=0
corebrum_greetd_gpu_groups
if [[ -s "${tmp}/usermod.log" ]]; then
  echo "FAIL: a missing greetd user was added to a GPU group" >&2
  exit 1
fi

ID_PRESENT=1
ID_GROUPS="_greetd"
corebrum_greetd_gpu_groups
if ! grep -qx -- '-aG video _greetd' "${tmp}/usermod.log"; then
  echo "FAIL: _greetd was not added to video" >&2
  exit 1
fi
if ! grep -qx -- '-aG render _greetd' "${tmp}/usermod.log"; then
  echo "FAIL: _greetd was not added to render" >&2
  exit 1
fi

: >"${tmp}/usermod.log"
ID_GROUPS="_greetd video render"
corebrum_greetd_gpu_groups
if [[ -s "${tmp}/usermod.log" ]]; then
  echo "FAIL: groups that _greetd already has were added again" >&2
  exit 1
fi

ID_GROUPS="_greetd"
DRY_RUN=1
dry_log="$(corebrum_greetd_gpu_groups 2>&1)"
DRY_RUN=0
if [[ -s "${tmp}/usermod.log" ]]; then
  echo "FAIL: dry-run changed _greetd groups" >&2
  exit 1
fi
if ! grep -q 'add _greetd to video and render' <<<"$dry_log"; then
  echo "FAIL: dry-run did not mention the GPU groups" >&2
  exit 1
fi

echo "ok: greetd groups"
