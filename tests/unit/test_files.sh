#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=../../scripts/lib/log.sh
source "${ROOT}/scripts/lib/log.sh"
# shellcheck source=../../scripts/lib/system.sh
source "${ROOT}/scripts/lib/system.sh"
# shellcheck source=../../scripts/lib/files.sh
source "${ROOT}/scripts/lib/files.sh"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
DRY_RUN=0
COREBRUM_STATE_FILE="${tmp}/state"
export DRY_RUN COREBRUM_STATE_FILE

src="${tmp}/src"
dest="${tmp}/dest"
printf 'same\n' >"$src"
cp "$src" "$dest"
corebrum_install_file "$src" "$dest" 644
if ! cmp -s "$src" "$dest"; then
  echo "FAIL: identical install changed the destination" >&2
  exit 1
fi
chmod 644 "$dest"
mode_log="$(corebrum_install_file "$src" "$dest" 755 2>&1)"
if [[ "$(stat -c %a "$dest")" != "755" ]]; then
  echo "FAIL: identical install left the destination non-executable" >&2
  printf '%s\n' "$mode_log" >&2
  exit 1
fi
if ! grep -q "updated mode of ${dest} to 755" <<<"$mode_log"; then
  echo "FAIL: identical install did not record the mode change" >&2
  printf '%s\n' "$mode_log" >&2
  exit 1
fi

corebrum_state_set_once example first
corebrum_state_set_once example second
count="$(grep -c '^example=' "$COREBRUM_STATE_FILE")"
if [[ "$count" -ne 1 ]]; then
  echo "FAIL: state key was recorded ${count} times" >&2
  exit 1
fi
if [[ "$(corebrum_state_get example)" != "first" ]]; then
  echo "FAIL: second state write replaced the first value" >&2
  exit 1
fi

export COREBRUM_ROOT="$ROOT"
# shellcheck source=../../scripts/lib/cli.sh
source "${ROOT}/scripts/lib/cli.sh"
COREBRUM_STATE_FILE="${tmp}/state"
COREBRUM_COMMAND_PATH="${tmp}/bin/corebrum"
export COREBRUM_STATE_FILE COREBRUM_COMMAND_PATH
link_log="$(corebrum_install_command 2>&1)"
link_log2="$(corebrum_install_command 2>&1)"
if ! grep -q "installed ${COREBRUM_COMMAND_PATH}" <<<"$link_log"; then
  echo "FAIL: first command install did not create the link" >&2
  exit 1
fi
if ! grep -q "unchanged: ${COREBRUM_COMMAND_PATH}" <<<"$link_log2"; then
  echo "FAIL: second command install rewrote an existing link" >&2
  printf '%s\n' "$link_log2" >&2
  exit 1
fi
if [[ "$(readlink -f "$COREBRUM_COMMAND_PATH")" != "$(readlink -f "${ROOT}/scripts/corebrum.sh")" ]]; then
  echo "FAIL: command link does not point at scripts/corebrum.sh" >&2
  exit 1
fi

echo "ok: files"
