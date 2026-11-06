# 0130. Super+S opens a floating terminal (Sway)

Date: 2026-11-06
Status: Accepted

## Context

Super+S toggled a Kitty window in the Sway scratchpad (`app_id=corebrum-agent`) next to Super+A, which also opened Kitty in a floating window (`corebrum-agent-float`). Operators expected Super+S to open a normal floating terminal and Super+A to open only the default catalog AI agent.

## Decision

- Super+S runs `/usr/local/bin/corebrum-float-terminal`, which starts `/usr/local/bin/corebrum-terminal --class corebrum-terminal-float`. Sway: `for_window [app_id="corebrum-terminal-float"] floating enable, resize set 920 560, move position center`.
- The session no longer `exec`s a hidden agent scratchpad Kitty or uses `move scratchpad` for that role. The old `/usr/local/bin/corebrum-agent-scratchpad` helper is removed; install/uninstall removes stale copies under `/usr/local/bin`.
- `corebrum-autotile` no longer skips a dedicated app id for the scratchpad; floating windows are still skipped.

## Consequences

Super+A behavior is unchanged (default agent via `corebrum-default-agent` → `corebrum-agents-menu default-open`). Super+S opens a new floating terminal each time. Keybindings and Getting Started text list Super+S as a floating terminal.
