# 0076. Corebrum Cloud is a Super+Space row

Date: 2026-10-27
Status: Accepted

## Context

Super+Space lists Corebrum Synapse and Corebrum Skills. Both rows use `/usr/share/corebrum/icon.png`. The cloud site is https://cloud.corebrum.com. The desktop profile already installs Firefox, and Super+Shift+Return launches `firefox`. Chromium stays an optional Super+Space install. See `docs/decisions/0014-chromium-menu.md`.

## Decision

- Super+Space lists Corebrum Cloud. The icon is `/usr/share/corebrum/icon.png`. That file stays the one copy from `config/brand/icon.png`.
- The launcher keeps its name sort. Corebrum Cloud follows Corebrum Synapse, and Corebrum Skills follows Corebrum Cloud.
- Choosing the row opens https://cloud.corebrum.com with `xdg-open`. When `xdg-open` is not on `PATH`, it runs `firefox` with that URL.
- The row does not install a browser, and it does not hide the address bar or browser tools.

## Consequences

The next Super+Space after the menu script is copied shows the row. Typing arc or cloud finds it. The row later opens Firefox directly. See `docs/decisions/0079-synapse-cloud-firefox.md`.
