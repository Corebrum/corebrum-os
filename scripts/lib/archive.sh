#!/usr/bin/env bash
# Ubuntu archive lookups. Source this file; do not execute it.
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  echo "source scripts/lib/archive.sh from another script" >&2
  exit 1
fi

# Print the apt candidate version, or nothing when the package is absent.
corebrum_archive_candidate() {
  local pkg="$1"
  local policy
  # Read the full policy first. Stopping awk early closes the pipe, apt-cache
  # dies with SIGPIPE, and pipefail then aborts the installer.
  policy="$(apt-cache policy "$pkg" 2>/dev/null || true)"
  awk '/^  Candidate:/ { print $2; exit }' <<<"$policy"
}

corebrum_candidate_installable() {
  local candidate="$1"
  [[ -n "$candidate" && "$candidate" != "(none)" ]]
}

# Quickshell is preferred when Ubuntu publishes it. Otherwise the session uses Waybar.
corebrum_shell_for_candidate() {
  if corebrum_candidate_installable "$1"; then
    printf 'quickshell\n'
  else
    printf 'waybar\n'
  fi
}
