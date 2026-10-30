# 0067. The Skills menu row uses the Corebrum Synapse mark

Date: 2026-10-26
Status: Accepted

## Context

Super+Space lists Skills with the generic `applications-science` icon. The Corebrum Synapse mark is already installed for the Corebrum Synapse row. See `docs/decisions/0064-synapse-menu-icon.md`.

## Decision

- The Skills row sets `Icon` to `/usr/share/corebrum/icon.png`.
- That file stays the one copy from `config/brand/icon.png`. Skills does not add a second image.

## Consequences

The next Super+Space after the Skills menu script is copied shows the same mark as Corebrum Synapse. The row is later named Corebrum Skills. See `docs/decisions/0074-corebrum-skills-name.md`.
