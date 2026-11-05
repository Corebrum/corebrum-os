# 0123. About ASCII banner

Date: 2026-11-05
Status: Accepted

## Context

`0110` prints the About card as three boxed sections. The card already uses a Kitty floating window. A short brand mark at the top makes the card read as Corebrum before the hardware and software rows.

## Decision

- `corebrum-about print` and the floating About window print a fixed `COREBRUM` ASCII banner before the Hardware section.
- The banner is baked into `scripts/desktop/corebrum-about.sh`. The desktop profile does not install `figlet`, `toilet`, or `fastfetch` for this.

## Consequences

`corebrum about` and Super+Space System → About show the same banner. Unit tests assert one banner line. The floating window size from `0110` still fits the card.
