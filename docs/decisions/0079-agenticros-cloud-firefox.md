# 0079. AgenticROS Cloud opens Firefox

Date: 2026-10-27
Status: Accepted

## Context

Decision 0076 opened https://cloud.agenticros.com with `xdg-open`. Super+Space writes a `NoDisplay` copy of `chromium_chromium.desktop` first on `XDG_DATA_DIRS`, and that copy runs `/bin/true` so the menu lists Chromium once. See `docs/decisions/0014-chromium-menu.md`. The Chromium snap lists that desktop ID ahead of Firefox for `x-scheme-handler/https`. `xdg-open` launched from the menu therefore runs `/bin/true` and no browser window appears. Getting Started and Super+Shift+Return already run `firefox`.

## Decision

- Choosing AgenticROS Cloud runs `firefox https://cloud.agenticros.com`.
- The row does not call `xdg-open`.
- The row does not install a browser, and it does not hide the address bar or browser tools.

## Consequences

The next Super+Space after the menu script is copied opens Firefox on the cloud site.
