#!/usr/bin/env bash
# Super+S: open a floating Kitty terminal (see Sway rule for app_id=corebrum-terminal-float).
# Keybind `exec` uses a minimal PATH and often omits HOME; set both.
set -euo pipefail

export PATH="/usr/local/bin:/usr/bin:/bin:${PATH:-}"

if [[ -z "${HOME:-}" ]] && command -v getent >/dev/null 2>&1; then
  HOME="$(getent passwd "$(id -un)" 2>/dev/null | cut -d: -f6 || true)"
  [[ -n "$HOME" ]] && export HOME
fi

exec /usr/local/bin/corebrum-terminal --class corebrum-terminal-float
