# 0064. The Corebrum Synapse menu row uses the Corebrum Synapse mark

Date: 2026-10-26
Status: Accepted

## Context

Super+Space lists Corebrum Synapse with the generic `applications-science` icon. The Corebrum Synapse site publishes a square mark at `https://corebrum.com/synapse/synapse-a.png`. Fuzzel already draws desktop icons.

## Decision

- The desktop profile copies that mark to `/usr/share/corebrum/icon.png`. The file in this checkout is `config/brand/icon.png`.
- The Corebrum Synapse row and its search actions set `Icon` to that path. The desktop profile does not install Corebrum Synapse itself.

## Consequences

The next Super+Space after the desktop files are copied shows the mark. Uninstall removes the file with the other Corebrum desktop files.
