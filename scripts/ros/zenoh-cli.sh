#!/usr/bin/env bash
# Zenoh client for the router started by corebrum install ros.
# A bare command connects to that router. Passing --mode, --connect,
# --listen, or --config leaves the session configuration to the caller.
set -euo pipefail

bin="${COREBRUM_ZENOH_CLI_BIN:-/opt/corebrum/zenoh-cli/bin/zenoh}"
if [[ ! -x "$bin" ]]; then
  echo "Zenoh CLI is not installed. Run: sudo corebrum install ros" >&2
  exit 1
fi

inject=1
for arg in "$@"; do
  case "$arg" in
    --mode | --mode=* | --connect | --connect=* | --listen | --listen=* | --config | --config=*)
      inject=0
      ;;
  esac
done

if [[ "$inject" -eq 1 ]]; then
  exec "$bin" \
    --mode client \
    --connect tcp/127.0.0.1:7447 \
    --cfg 'scouting/multicast/enabled:false' \
    "$@"
fi
exec "$bin" "$@"
