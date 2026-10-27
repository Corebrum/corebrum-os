# 0076. AgenticROS Cloud is a Super+Space row

Date: 2026-10-27
Status: Accepted

## Context

Super+Space lists AgenticROS and AgenticROS Skills. Both rows use `/usr/share/corebrum/agenticros.png`. The cloud site is https://cloud.agenticros.com. The desktop profile already installs Firefox, and Super+Shift+Return launches `firefox`. Chromium stays an optional Super+Space install. See `docs/decisions/0014-chromium-menu.md`.

## Decision

- Super+Space lists AgenticROS Cloud (ARC). The icon is `/usr/share/corebrum/agenticros.png`. That file stays the one copy from `config/brand/agenticros.png`.
- The launcher keeps its name sort. AgenticROS Cloud (ARC) follows AgenticROS, and AgenticROS Skills follows AgenticROS Cloud (ARC).
- Choosing the row opens https://cloud.agenticros.com with `xdg-open`. When `xdg-open` is not on `PATH`, it runs `firefox` with that URL.
- The row does not install a browser, and it does not hide the address bar or browser tools.

## Consequences

The next Super+Space after the menu script is copied shows the row. Typing arc or cloud finds it. The row later opens Firefox directly. See `docs/decisions/0079-agenticros-cloud-firefox.md`.
