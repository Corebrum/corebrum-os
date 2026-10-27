#!/usr/bin/env bash
# Start the Getting Started server with the desktop Node.js 26 binary.
set -euo pipefail

# shellcheck source=corebrum-node-path.sh
source /usr/local/lib/corebrum/node-path.sh
corebrum_node_prepare_path
if ! command -v node >/dev/null 2>&1; then
  printf 'corebrum-getting-started: Node.js 26 is not installed\n' >&2
  exit 1
fi
exec node /usr/local/lib/corebrum/getting-started-server.js
