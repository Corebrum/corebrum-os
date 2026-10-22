#!/usr/bin/env bash
# Node.js profile and installer pins. Does not clone nvm or download Node.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
profile="${ROOT}/config/profile.d/corebrum-node.sh"
node_lib="${ROOT}/scripts/lib/node.sh"
versions="${ROOT}/manifests/versions/node.txt"

require_file() {
  local file="$1"
  local needle="$2"
  if ! grep -qF -- "$needle" "$file"; then
    echo "FAIL: ${file} missing ${needle}" >&2
    exit 1
  fi
}

require_file "$versions" "v0.40.8"
require_file "$versions" "a885b885fef16fac4bc544188fb25e9e37ae83e8"
require_file "$versions" "12.15.0"
require_file "$node_lib" 'COREBRUM_NVM_DIR="/usr/local/nvm"'
require_file "$node_lib" 'COREBRUM_NVM_TAG="v0.40.8"'
require_file "$node_lib" 'COREBRUM_NVM_COMMIT="a885b885fef16fac4bc544188fb25e9e37ae83e8"'
require_file "$node_lib" 'COREBRUM_PNPM_VERSION="12.15.0"'
require_file "$node_lib" "refusing to replace it"
require_file "$node_lib" 'corebrum_install_node'
require_file "${ROOT}/scripts/phases/02-desktop.sh" "corebrum_install_node"
require_file "${ROOT}/scripts/desktop/corebrum-session.sh" "/etc/profile.d/corebrum-node.sh"
require_file "${ROOT}/scripts/desktop/corebrum-terminal.sh" "/etc/profile.d/corebrum-node.sh"
require_file "${ROOT}/config/kitty/kitty.conf" "shell bash --login"
require_file "$profile" 'NVM_DIR="/usr/local/nvm"'
require_file "$profile" 'BASH_VERSION'

# Literal path search. These strings must not appear in the installer.
# shellcheck disable=SC2088,SC2016
if grep -q '~/.bashrc\|~/.nvm\|$HOME/.nvm' "$node_lib" "$profile"; then
  echo "FAIL: the Node installer references a home-directory nvm or bashrc path" >&2
  exit 1
fi

clean="$(bash --noprofile --norc -c "set +u; . $(printf '%q' "$profile"); case \$- in *u*) echo nounset;; *) echo clean;; esac")"
if [[ "$clean" != "clean" ]]; then
  echo "FAIL: the node profile enabled nounset" >&2
  exit 1
fi

kept="$(bash --noprofile --norc -c "set -u; . $(printf '%q' "$profile"); case \$- in *u*) echo kept;; *) echo lost;; esac")"
if [[ "$kept" != "kept" ]]; then
  echo "FAIL: the node profile cleared nounset" >&2
  exit 1
fi

echo "ok: node"
