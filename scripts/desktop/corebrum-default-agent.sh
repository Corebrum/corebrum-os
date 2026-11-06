#!/usr/bin/env bash
# Super+A: open the default AI agent in a floating Kitty (see corebrum-agents-menu default-open).
# Keybind `exec` uses a minimal PATH; ensure /usr/local/bin is present for nested scripts.
set -euo pipefail

export PATH="/usr/local/bin:/usr/bin:/bin:${PATH:-}"

# Sway keybind `exec` often omits HOME; corebrum-agents-menu and kitty need it
# for ~/.local/bin (agy) and config paths.
if [[ -z "${HOME:-}" ]] && command -v getent >/dev/null 2>&1; then
  HOME="$(getent passwd "$(id -un)" 2>/dev/null | cut -d: -f6 || true)"
  [[ -n "$HOME" ]] && export HOME
fi

set +e
/usr/local/bin/corebrum-agents-menu default-open
ec=$?
set -e
if [[ "$ec" -ne 0 ]] && command -v notify-send >/dev/null 2>&1; then
  notify-send --app-name=Corebrum --urgency=normal \
    "AI Agents" "Super+A failed. Check that /etc/corebrum/agents.conf is installed (e.g. sudo corebrum install desktop)." \
    || true
fi
