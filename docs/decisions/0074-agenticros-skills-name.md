# 0074. The skills row is named AgenticROS Skills

Date: 2026-10-27
Status: Accepted

## Context

Super+Space lists the skills row as Skills. The idle list is sorted by name, so Skills sits with the other S entries instead of next to AgenticROS.

## Decision

- The row name is AgenticROS Skills. The icon stays `/usr/share/corebrum/agenticros.png`.
- The submenu prompt uses that same name. Typing skills still finds the row.
- The launcher keeps its name sort. AgenticROS Skills follows AgenticROS.

## Consequences

The next Super+Space after the skills menu script is copied shows the new name in that order.
