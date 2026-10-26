#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export COREBRUM_ROOT="$ROOT"
# shellcheck source=../../scripts/lib/log.sh
source "${ROOT}/scripts/lib/log.sh"
# shellcheck source=../../scripts/lib/ros.sh
source "${ROOT}/scripts/lib/ros.sh"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

mkdir -p "${tmp}/apt/sources.list.d"
cat >"${tmp}/apt/sources.list.d/ubuntu.sources" <<'EOF'
# <name>-updates is only a comment here.
Types: deb
URIs: http://archive.ubuntu.com/ubuntu/
Suites: resolute
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg

Types: deb
URIs: http://archive.ubuntu.com/ubuntu/
Suites: resolute-security
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg
EOF

fields="$(corebrum_ros_release_source_fields "${tmp}/apt/sources.list.d/ubuntu.sources" resolute)"
if [[ "$(sed -n '1p' <<<"$fields")" != "http://archive.ubuntu.com/ubuntu/" ]]; then
  echo "FAIL: release stanza URI was not read" >&2
  exit 1
fi
if [[ "$(sed -n '2p' <<<"$fields")" != "main restricted universe multiverse" ]]; then
  echo "FAIL: release stanza components were not read" >&2
  exit 1
fi

export COREBRUM_APT_ROOT="${tmp}/apt"
export COREBRUM_ROS_CODENAME="resolute"
DRY_RUN=1
added="$(corebrum_ros_require_suites 2>&1)"
if ! grep -q 'corebrum-ubuntu-updates.sources' <<<"$added"; then
  echo "FAIL: a missing updates pocket should be added beside ubuntu.sources" >&2
  exit 1
fi
if ! grep -q 'not editing' <<<"$added"; then
  echo "FAIL: the updates pocket should leave ubuntu.sources unchanged" >&2
  exit 1
fi
if [[ -e "${tmp}/apt/sources.list.d/corebrum-ubuntu-updates.sources" ]]; then
  echo "FAIL: dry-run wrote the updates source" >&2
  exit 1
fi

printf '\nSuites: resolute-updates\n' >>"${tmp}/apt/sources.list.d/ubuntu.sources"
present="$(corebrum_ros_require_suites 2>&1)"
if grep -q 'corebrum-ubuntu-updates.sources' <<<"$present"; then
  echo "FAIL: an existing updates pocket should not gain a second source" >&2
  exit 1
fi

cat >"${tmp}/apt/sources.list.d/ubuntu.sources" <<'EOF'
Types: deb
URIs: http://archive.ubuntu.com/ubuntu/
Suites: resolute
Components: main restricted
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg
EOF
set +e
missing="$(corebrum_ros_require_suites 2>&1)"
missing_status=$?
set -e
if [[ "$missing_status" -eq 0 ]] || ! grep -q 'must include universe' <<<"$missing"; then
  echo "FAIL: a source without universe should still stop" >&2
  exit 1
fi

echo "ok: ros-sources"
