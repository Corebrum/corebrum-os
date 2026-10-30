# 0074. The skills row is named Corebrum Skills

Date: 2026-10-27
Status: Accepted

## Context

Super+Space lists the skills row as Skills. The idle list is sorted by name, so Skills sits with the other S entries instead of next to Corebrum Synapse.

## Decision

- The row name is Corebrum Skills. The icon stays `/usr/share/corebrum/icon.png`.
- The submenu prompt uses that same name. Typing skills still finds the row.
- The launcher keeps its name sort. Corebrum Skills follows Corebrum Synapse.

## Consequences

The next Super+Space after the skills menu script is copied shows the new name in that order.
