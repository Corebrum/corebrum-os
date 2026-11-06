# 0129. Default AI agent on Super+A (Sway)

Date: 2026-11-06
Status: Accepted

## Context

Operators install several publisher CLIs from Super+Space → AI Agents (a top-level group). Super+Return opens a tiled Kitty. There was no shortcut that re-opens one chosen CLI without going through the menu.

## Decision

- `${XDG_STATE_HOME:-~/.local/state}/corebrum/default-agent` stores one catalog **id** (see `/etc/corebrum/agents.conf`). Invalid ids are cleared on Super+A with a notification.
- The AI Agents Fuzzel menu lists **Super+A default: Clear** and **Super+A default: Set** before the per-CLI rows. Set opens a second Fuzzel list: **Default: &lt;Label&gt;** for each catalog entry.
- **Super+A** runs `/usr/local/bin/corebrum-default-agent`, which runs `corebrum-agents-menu default-open`. When the default is set and that CLI passes the same **ready** checks as the menu, it launches with `/usr/local/bin/corebrum-terminal --class corebrum-agent-float` and `bash --login -c` (same Synapse MCP coupling as `corebrum_agents_launch`). Otherwise it sends a **notify-send** message and does not run an installer.
- Sway: `for_window [app_id="corebrum-terminal-float"]` and `for_window [app_id="corebrum-agent-float"]` both float, `resize set 920 560`, `move position center`.
- `corebrum agents default get|set <id>|clear` delegates to `corebrum-agents-menu default-*`.

## Consequences

Super+S runs `/usr/local/bin/corebrum-float-terminal`, which starts Kitty with `app_id=corebrum-terminal-float`; Sway floats and centers it like the Super+A agent window. Each Super+A can open another floating agent terminal. Hyprland config is unchanged (Sway-only). Operators can script `corebrum agents default set cursor` once the CLI is installed.
