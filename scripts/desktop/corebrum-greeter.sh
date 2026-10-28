#!/usr/bin/env bash
# Login client for the greeter Sway. The centered card is corebrum-login.
# If that client cannot start, wlgreet is the fallback and the logo helper
# sits above its fixed 1024x128 bar.
set -euo pipefail

export GDK_BACKEND="${GDK_BACKEND:-wayland}"

if [[ -x /usr/local/bin/corebrum-login ]]; then
  if /usr/local/bin/corebrum-login; then
    exit 0
  fi
fi

if [[ -x /usr/sbin/wlgreet ]]; then
  if [[ -x /usr/local/bin/corebrum-login-logo ]]; then
    /usr/local/bin/corebrum-login-logo &
  fi
  exec /usr/sbin/wlgreet --config /etc/corebrum/greetd/wlgreet.toml
fi

printf 'corebrum-greeter: no login screen is installed\n' >&2
exit 1
