#!/usr/bin/env bash
# The one client cage runs for the login screen. cage exits when this process exits.
set -euo pipefail

if [[ ! -x /usr/sbin/wlgreet ]]; then
  printf 'corebrum-greeter: wlgreet is not installed\n' >&2
  exit 1
fi

exec /usr/sbin/wlgreet --config /etc/corebrum/greetd/wlgreet.toml
