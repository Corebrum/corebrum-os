# 0067. The Skills menu row uses the AgenticROS mark

Date: 2026-10-26
Status: Accepted

## Context

Super+Space lists Skills with the generic `applications-science` icon. The AgenticROS mark is already installed for the AgenticROS row. See `docs/decisions/0064-agenticros-menu-icon.md`.

## Decision

- The Skills row sets `Icon` to `/usr/share/corebrum/agenticros.png`.
- That file stays the one copy from `config/brand/agenticros.png`. Skills does not add a second image.

## Consequences

The next Super+Space after the Skills menu script is copied shows the same mark as AgenticROS. The row is later named AgenticROS Skills. See `docs/decisions/0074-agenticros-skills-name.md`.
