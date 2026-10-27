# 0078. Super+Space opens Getting Started

Date: 2026-10-27
Status: Accepted

## Context

Firefox opens `http://127.0.0.1:8765/getting-started/` when that page is still the homepage. See `docs/decisions/0077-getting-started-homepage.md`. A new tab, or a homepage the operator changed, leaves no menu path back to the guide. Super+Space is where the other desktop rows are found.

## Decision

- Super+Space lists Getting Started. The icon is `/usr/share/corebrum/logo.png`.
- Choosing the row runs `firefox http://127.0.0.1:8765/getting-started/`.
- Typing docs, help, or guide finds the row.
- The row does not install a browser, and it does not install Chromium.

## Consequences

The next Super+Space after the menu script is copied shows the row. Firefox opens the welcome page. The local Node server from decision 0077 has to be running for the page to load.
