#!/usr/bin/env bash
# Fail if a dry-run executes apt, locale, time, or service commands.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
shim_dir="$(mktemp -d)"
trap 'rm -rf "$shim_dir"' EXIT

for cmd in apt-get locale-gen timedatectl systemctl dpkg; do
  printf '#!/bin/sh\necho "forbidden command: %s $*" >&2\nexit 99\n' "$cmd" >"${shim_dir}/${cmd}"
  chmod +x "${shim_dir}/${cmd}"
done

run_dry() {
  PATH="${shim_dir}:${PATH}" "${ROOT}/scripts/install.sh" "$@" 2>&1
}

assert_dry_run() {
  local status output
  set +e
  output="$(run_dry "$@")"
  status=$?
  set -e
  if [[ "$status" -ne 0 ]]; then
    printf '%s\n' "$output" >&2
    echo "FAIL: dry-run exited ${status}" >&2
    exit 1
  fi
  if grep -q 'forbidden command' <<<"$output"; then
    printf '%s\n' "$output" >&2
    echo "FAIL: dry-run invoked a mutating command" >&2
    exit 1
  fi
  printf '%s\n' "$output"
}

output="$(assert_dry_run --profile base --dry-run)"
if ! grep -q 'base profile dry-run complete' <<<"$output"; then
  printf '%s\n' "$output" >&2
  echo "FAIL: dry-run did not finish the base profile" >&2
  exit 1
fi
if ! grep -q 'ca-certificates' <<<"$output"; then
  echo "FAIL: dry-run did not list base packages" >&2
  exit 1
fi
if grep -q 'systemctl enable --now ssh' <<<"$output"; then
  echo "FAIL: dry-run enabled ssh without --enable-ssh" >&2
  exit 1
fi

ssh_output="$(assert_dry_run --profile base --dry-run --enable-ssh)"
if ! grep -q 'systemctl enable --now ssh' <<<"$ssh_output"; then
  printf '%s\n' "$ssh_output" >&2
  echo "FAIL: --enable-ssh dry-run did not show the ssh action" >&2
  exit 1
fi
if ! grep -q 'openssh-server' <<<"$ssh_output"; then
  echo "FAIL: --enable-ssh dry-run did not list openssh-server" >&2
  exit 1
fi

echo "ok: dry-run"
