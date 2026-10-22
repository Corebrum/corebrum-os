#!/usr/bin/env bash
# The one client cage runs for the login screen. cage exits when this process exits.
set -euo pipefail

exec gtkgreet \
  --command /usr/local/bin/corebrum-session \
  --style /etc/corebrum/greetd/gtkgreet.css
