#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=../../scripts/lib/log.sh
source "${ROOT}/scripts/lib/log.sh"
# shellcheck source=../../scripts/lib/cortex.sh
source "${ROOT}/scripts/lib/cortex.sh"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "${tmp}/bin" "${tmp}/os" "${tmp}/home"
export HOME="${tmp}/home"
export COREBRUM_ROOT="${tmp}/os"
export COREBRUM_CORTEX_URL="git@github.com:Corebrum/corebrum-cortex.git"
git_log="${tmp}/git.log"

cat >"${tmp}/bin/git" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >>"${git_log}"
if [[ "\$1" == clone ]]; then
  dest="\${@: -1}"
  mkdir -p "\$dest"
  printf '[package]\nname = "cortex"\n' >"\${dest}/Cargo.toml"
fi
exit 0
EOF
chmod +x "${tmp}/bin/git"
export PATH="${tmp}/bin:${PATH}"

got="$(corebrum_cortex_prepare)"
[[ "$got" == "${tmp}/corebrum-cortex" ]] || {
  echo "FAIL: missing checkout was not cloned beside Corebrum: ${got}" >&2
  exit 1
}
grep -qF "clone --depth 1 ${COREBRUM_CORTEX_URL} ${tmp}/corebrum-cortex" "$git_log"
: >"$git_log"
again="$(corebrum_cortex_prepare)"
[[ "$again" == "$got" ]] || {
  echo "FAIL: existing checkout was not reused" >&2
  exit 1
}
[[ ! -s "$git_log" ]] || {
  echo "FAIL: existing checkout was cloned again" >&2
  exit 1
}

export COREBRUM_ROOT="${tmp}/missing/os"
got="$(corebrum_cortex_prepare)"
[[ "$got" == "${HOME}/corebrum-cortex" ]] || {
  echo "FAIL: unwritable sibling did not clone into the home directory: ${got}" >&2
  exit 1
}
grep -qF "clone --depth 1 ${COREBRUM_CORTEX_URL} ${HOME}/corebrum-cortex" "$git_log"

echo "ok"
