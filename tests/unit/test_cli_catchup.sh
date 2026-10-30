#!/usr/bin/env bash
# Report commands name the menus and do not install or upgrade.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CMD="${ROOT}/scripts/corebrum.sh"
cli="${ROOT}/scripts/lib/cli.sh"

help="$("$CMD" help)"
for name in "camera list" "agents list" "update status"; do
  if ! grep -q "$name" <<<"$help"; then
    echo "FAIL: help does not name ${name}" >&2
    exit 1
  fi
done

marker="$(mktemp)"
stub="$(mktemp -d)"
trap 'rm -rf "$stub" "$marker"' EXIT
cat >"${stub}/apt" <<EOF
#!/bin/sh
printf '%s\n' apt >>"${marker}"
exit 99
EOF
cp "${stub}/apt" "${stub}/apt-get"
cp "${stub}/apt" "${stub}/git"
cat >"${stub}/dpkg-query" <<'EOF'
#!/bin/sh
exit 1
EOF
chmod 755 "${stub}/apt" "${stub}/apt-get" "${stub}/git" "${stub}/dpkg-query"

update="$(PATH="${stub}:${PATH}" "$CMD" update status)"
if [[ -s "$marker" ]]; then
  echo "FAIL: update status called apt or git" >&2
  exit 1
fi
for row in Ubuntu Corebrum "ROS 2" Zenoh Corebrum Synapse "AI Agents"; do
  if ! grep -q "$row" <<<"$update"; then
    echo "FAIL: update status omitted ${row}" >&2
    exit 1
  fi
done
if PATH="${stub}:${PATH}" "$CMD" update system >/dev/null 2>&1; then
  echo "FAIL: update system should refuse" >&2
  exit 1
fi
if [[ -s "$marker" ]]; then
  echo "FAIL: a refused update called apt or git" >&2
  exit 1
fi

camera="$(PATH="${stub}:${PATH}" "$CMD" camera list)"
if ! grep -q 'Super+Space' <<<"$camera"; then
  echo "FAIL: camera list did not point at Super+Space when the SDK is missing" >&2
  exit 1
fi

catalog="$(mktemp)"
bin="$(mktemp -d)"
trap 'rm -rf "$stub" "$marker" "$bin" "$catalog"' EXIT
printf '%s\n' 'demo^Demo^present^script^true^present' >"$catalog"
printf '%s\n' 'other^Other^absent^script^true^absent' >>"$catalog"
printf '#!/bin/sh\nexit 0\n' >"${bin}/present"
printf '#!/bin/sh\nif [ "$1" = --version ]; then echo "present 1.2.3"; fi\nexit 0\n' >"${bin}/versioned"
chmod 755 "${bin}/present" "${bin}/versioned"
printf '%s\n' 'numbered^Numbered^versioned^script^true^versioned' >>"$catalog"
agents="$(PATH="${bin}:${PATH}" COREBRUM_AGENTS_FILE="$catalog" "$CMD" agents list)"
if ! grep -qx 'present: installed' <<<"$agents"; then
  echo "FAIL: agents list missed an installed CLI" >&2
  exit 1
fi
if ! grep -qx 'versioned: installed (present 1.2.3)' <<<"$agents"; then
  echo "FAIL: agents list missed a version" >&2
  exit 1
fi
update="$(PATH="${bin}:${PATH}" COREBRUM_AGENTS_FILE="$catalog" "$CMD" agents update)"
if ! grep -q 'Super+Space Updates' <<<"$update"; then
  echo "FAIL: agents update did not point at Super+Space" >&2
  exit 1
fi
if grep -q 'curl' <<<"$update"; then
  echo "FAIL: agents update ran an installer" >&2
  exit 1
fi
if ! grep -qx 'absent: not installed' <<<"$agents"; then
  echo "FAIL: agents list missed a missing CLI" >&2
  exit 1
fi

if awk '
  /doctor: realsense is not installed/ { show = 1 }
  show { print }
  show && /duplicates=/ { exit }
' "$cli" | grep -q 'failed=1'; then
  echo "FAIL: a missing optional report fails doctor" >&2
  exit 1
fi
